/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;
import '../features/operations/endpoints/operations_endpoint.dart' as _i9ed7jwa;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'operations': _i9ed7jwa.OperationsEndpoint()
        ..initialize(server, 'operations', null),
    };
    connectors['operations'] = _is.EndpointConnector(
      name: 'operations',
      endpoint: endpoints['operations']!,
      methodConnectors: {
        'execute': _is.MethodConnector(
          name: 'execute',
          params: {
            'command': _is.ParameterDescription(
              name: 'command',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'payload': _is.ParameterDescription(
              name: 'payload',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'requestId': _is.ParameterDescription(
              name: 'requestId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['operations'] as _i9ed7jwa.OperationsEndpoint).execute(
                session,
                params['command'],
                params['payload'],
                params['requestId'],
              ),
        ),
      },
    );
  }
}
