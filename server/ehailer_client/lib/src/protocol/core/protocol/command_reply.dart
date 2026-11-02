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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class CommandReply
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  CommandReply._({required this.dataJson, this.errorCode, this.errorMessage});

  factory CommandReply({
    required String dataJson,
    String? errorCode,
    String? errorMessage,
  }) = _CommandReplyImpl;

  factory CommandReply.fromJson(Map<String, dynamic> jsonSerialization) {
    return CommandReply(
      dataJson: jsonSerialization['dataJson'] as String,
      errorCode: jsonSerialization['errorCode'] as String?,
      errorMessage: jsonSerialization['errorMessage'] as String?,
    );
  }

  String dataJson;

  String? errorCode;

  String? errorMessage;

  /// Returns a shallow copy of this [CommandReply]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  CommandReply copyWith({
    String? dataJson,
    String? errorCode,
    String? errorMessage,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CommandReply',
      'dataJson': dataJson,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CommandReply',
      'dataJson': dataJson,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CommandReplyImpl extends CommandReply {
  _CommandReplyImpl({
    required String dataJson,
    String? errorCode,
    String? errorMessage,
  }) : super._(
         dataJson: dataJson,
         errorCode: errorCode,
         errorMessage: errorMessage,
       );

  /// Returns a shallow copy of this [CommandReply]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  CommandReply copyWith({
    String? dataJson,
    Object? errorCode = _Undefined,
    Object? errorMessage = _Undefined,
  }) {
    return CommandReply(
      dataJson: dataJson ?? this.dataJson,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      errorMessage: errorMessage is String? ? errorMessage : this.errorMessage,
    );
  }
}
