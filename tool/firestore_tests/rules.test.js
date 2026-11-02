import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where, writeBatch } from 'firebase/firestore';

let env;
const projectId = 'demo-ehailer';
const profile = (uid, role = 'customer') => ({uid, role, fullName: uid, email: `${uid}@example.test`, phone: '08000000000', avatarUrl: null, walletBalance: 0, rating: 5, isAvailable: false, vehicleType: role === 'driver' ? 'car' : null, vehiclePlateNumber: null, vehicleModel: null, createdAt: '2026-10-28T00:00:00Z'});
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run with the local Firebase emulator.');
  env = await initializeTestEnvironment({projectId, firestore: {rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const store = context.firestore();
    for (const [uid, role] of [['customer','customer'],['other','customer'],['driver','driver'],['admin','admin'],['support','support']]) await setDoc(doc(store, 'users', uid), profile(uid, role));
    await setDoc(doc(store, 'deliveries', 'order'), {customerId:'customer', driverId:'driver', status:'inTransit', pricing:{totalFare:1700}});
    await setDoc(doc(store, 'deliveries/order/timeline/event'), {status:'inTransit'});
    await setDoc(doc(store, 'deliveryPins/order'), {customerId:'customer', pin:'7429'});
    await setDoc(doc(store, 'publicTracking/random-token'), {status:'inTransit', expiresAtMillis: Date.now() + 60000});
    await setDoc(doc(store, 'publicTracking/expired-token'), {status:'delivered', expiresAtMillis: 1});
    await setDoc(doc(store, 'jobOffers/order'), {status:'searchingDriver'});
    await setDoc(doc(store, 'payouts/payout'), {driverId:'driver', status:'pending'});
    await setDoc(doc(store, 'disputes/ticket'), {claimantId:'customer', targetDriverId:'driver', status:'open'});
  });
});

test('private deliveries and timeline require a participant or staff', async () => {
  for (const uid of [undefined, 'other']) {
    await assertFails(getDoc(doc(db(uid), 'deliveries/order')));
    await assertFails(getDoc(doc(db(uid), 'deliveries/order/timeline/event')));
  }
  for (const uid of ['customer','driver','admin','support']) await assertSucceeds(getDoc(doc(db(uid), 'deliveries/order')));
});
test('customer can query their own deliveries but cannot enumerate all orders', async () => {
  await assertSucceeds(getDocs(query(collection(db('customer'), 'deliveries'), where('customerId', '==', 'customer'))));
  await assertFails(getDocs(collection(db('customer'), 'deliveries')));
});
test('PIN is readable only by the booking customer, including against staff', async () => {
  await assertSucceeds(getDoc(doc(db('customer'), 'deliveryPins/order')));
  for (const uid of [undefined,'other','driver','admin','support']) await assertFails(getDoc(doc(db(uid), 'deliveryPins/order')));
  await assertFails(getDocs(collection(db('customer'), 'deliveryPins')));
});
test('public access is a single unexpired projection, never a list', async () => {
  await assertSucceeds(getDoc(doc(db(), 'publicTracking/random-token')));
  await assertFails(getDoc(doc(db(), 'publicTracking/expired-token')));
  await assertFails(getDocs(collection(db(), 'publicTracking')));
});
test('no client role can change a financial or lifecycle document', async () => {
  for (const uid of ['customer','driver','admin','support']) {
    for (const [path, data] of [
      ['deliveries/order', {status:'delivered'}],
      ['deliveryPins/order', {pin:'0000'}],
      ['payouts/payout', {status:'settled'}],
      ['disputes/ticket', {status:'resolvedRefund'}],
      ['publicTracking/random-token', {status:'delivered'}],
    ]) await assertFails(updateDoc(doc(db(uid), path), data));
    await assertFails(setDoc(doc(db(uid), `users/${uid}/transactions/credit`), {amount:1000}));
  }
});
test('self service profile updates cannot promote a role or change balances', async () => {
  const target = doc(db('customer'), 'users/customer');
  await assertSucceeds(updateDoc(target, {fullName:'Updated name', phone:'08012345678'}));
  for (const data of [{role:'admin'},{walletBalance:99999},{rating:4},{currentOrderId:'order'},{activeOrderIds:[]},{totalTrips:50},{uid:'other'}]) await assertFails(updateDoc(target,data));
});
test('new profiles support customer and driver only with zero balance', async () => {
  for (const role of ['customer','driver']) await assertSucceeds(setDoc(doc(db(`new-${role}`), `users/new-${role}`),profile(`new-${role}`,role)));
  for (const role of ['admin','support']) await assertFails(setDoc(doc(db(`new-${role}`), `users/new-${role}`),profile(`new-${role}`,role)));
  await assertFails(setDoc(doc(db('rich'), 'users/rich'), {...profile('rich'), walletBalance:1}));
  await assertFails(setDoc(doc(db('extra'), 'users/extra'), {...profile('extra'), totalTrips:999}));
});
test('driver vehicle names match Flutter and customer cannot become available', async () => {
  await assertSucceeds(updateDoc(doc(db('driver'), 'users/driver'), {vehicleType:'car',isAvailable:true}));
  await assertFails(updateDoc(doc(db('driver'), 'users/driver'), {vehicleType:'sedan'}));
  await assertFails(updateDoc(doc(db('customer'), 'users/customer'), {isAvailable:true}));
});
test('forged batch cannot debit a user and create a delivery', async () => {
  const store = db('customer'); const batch = writeBatch(store);
  batch.update(doc(store, 'users/customer'), {walletBalance:1000});
  batch.set(doc(store, 'deliveries/fake'), {customerId:'customer',status:'delivered'});
  await assertFails(batch.commit());
});
test('only drivers read job offers and only staff enumerate users', async () => {
  await assertSucceeds(getDocs(collection(db('driver'), 'jobOffers')));
  for (const uid of [undefined,'customer']) await assertFails(getDocs(collection(db(uid), 'jobOffers')));
  await assertFails(getDocs(collection(db('customer'), 'users')));
  await assertSucceeds(getDocs(collection(db('admin'), 'users')));
});
test('payouts stay private and support has no financial access', async () => {
  for (const uid of ['driver','admin']) await assertSucceeds(getDoc(doc(db(uid), 'payouts/payout')));
  for (const uid of [undefined,'customer','support']) await assertFails(getDoc(doc(db(uid), 'payouts/payout')));
});
test('receipts and unmatched collections are always denied', async () => {
  for (const uid of [undefined,'customer','admin']) {
    await assertFails(getDoc(doc(db(uid), 'commandReceipts/key')));
    await assertFails(setDoc(doc(db(uid), 'otherCollections/key'), {data:true}));
  }
});

test('payment intents, settlements and pending-wallet pointers are server-owned', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'paymentIntents/reference'), {uid:'customer', email:'private@example.test', amountMinor:50000});
    await setDoc(doc(context.firestore(), 'paymentSettlements/provider-id'), {uid:'customer', amountMinor:50000});
  });
  for (const uid of [undefined,'customer','driver','admin','support']) {
    for (const path of ['paymentIntents/reference','paymentSettlements/provider-id']) {
      await assertFails(getDoc(doc(db(uid),path)));
      await assertFails(setDoc(doc(db(uid),path),{status:'credited'}));
    }
  }
  await assertFails(updateDoc(doc(db('customer'),'users/customer'),{pendingTopUpReference:'forged'}));
});
