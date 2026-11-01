// The Network framework C API the Network Swift overlay wraps, written for Darling. Darling's
// Network.framework re-exports libnetwork (src/external/libnetwork), whose headers declare its
// entry points as `void *f(void)` stubs, so the overlay imports these typed declarations instead.
// Every prototype, block type and enumerator name is the one documented under
// https://developer.apple.com/documentation/network (C declarations; nullability from the Swift
// declarations on the same pages). The documentation does not give enumerator values: the values
// of nw_connection_state_t and nw_path_status_t are libnetwork's (include/nw/connection.h,
// include/nw/path.h); the others count from 0 in the documented order, with the neutral or
// default case first. The five functions under "Not documented" are libnetwork exports whose
// prototypes follow the 5.2.2 overlay's calls. sec_protocol_options_t and sec_protocol_metadata_t are
// Darling's Security headers' (SecProtocolObject.h).
#ifndef DARLING_NETWORK_H
#define DARLING_NETWORK_H

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <os/object.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/socket.h>
#include <dns_sd.h>
#include <Security/SecBase.h>
#include <Security/SecProtocolObject.h>

NS_ASSUME_NONNULL_BEGIN

OS_OBJECT_DECL_CLASS(nw_advertise_descriptor);
OS_OBJECT_DECL_CLASS(nw_connection);
OS_OBJECT_DECL_CLASS(nw_content_context);
OS_OBJECT_DECL_CLASS(nw_endpoint);
OS_OBJECT_DECL_CLASS(nw_error);
OS_OBJECT_DECL_CLASS(nw_interface);
OS_OBJECT_DECL_CLASS(nw_listener);
OS_OBJECT_DECL_CLASS(nw_parameters);
OS_OBJECT_DECL_CLASS(nw_path);
OS_OBJECT_DECL_CLASS(nw_path_monitor);
OS_OBJECT_DECL_CLASS(nw_protocol_definition);
OS_OBJECT_DECL_CLASS(nw_protocol_metadata);
OS_OBJECT_DECL_CLASS(nw_protocol_options);
OS_OBJECT_DECL_CLASS(nw_protocol_stack);

typedef enum {
	nw_connection_state_invalid = 0,
	nw_connection_state_waiting = 1,
	nw_connection_state_preparing = 2,
	nw_connection_state_ready = 3,
	nw_connection_state_failed = 4,
	nw_connection_state_cancelled = 5,
} nw_connection_state_t;

typedef enum {
	nw_path_status_satisfied = 0,
	nw_path_status_unsatisfied = 1,
	nw_path_status_satisfiable = 2,
	nw_path_status_invalid = 3,
} nw_path_status_t;

typedef enum {
	nw_listener_state_invalid = 0,
	nw_listener_state_waiting = 1,
	nw_listener_state_ready = 2,
	nw_listener_state_failed = 3,
	nw_listener_state_cancelled = 4,
} nw_listener_state_t;

typedef enum {
	nw_interface_type_other = 0,
	nw_interface_type_wifi = 1,
	nw_interface_type_cellular = 2,
	nw_interface_type_wired = 3,
	nw_interface_type_loopback = 4,
} nw_interface_type_t;

typedef enum {
	nw_endpoint_type_invalid = 0,
	nw_endpoint_type_address = 1,
	nw_endpoint_type_host = 2,
	nw_endpoint_type_bonjour_service = 3,
	nw_endpoint_type_url = 4,
} nw_endpoint_type_t;

typedef enum {
	nw_error_domain_invalid = 0,
	nw_error_domain_posix = 1,
	nw_error_domain_dns = 2,
	nw_error_domain_tls = 3,
} nw_error_domain_t;

typedef enum {
	nw_ip_version_any = 0,
	nw_ip_version_4 = 1,
	nw_ip_version_6 = 2,
} nw_ip_version_t;

typedef enum {
	nw_ip_ecn_flag_non_ect = 0,
	nw_ip_ecn_flag_ect_0 = 1,
	nw_ip_ecn_flag_ect_1 = 2,
	nw_ip_ecn_flag_ce = 3,
} nw_ip_ecn_flag_t;

typedef enum {
	nw_service_class_best_effort = 0,
	nw_service_class_background = 1,
	nw_service_class_interactive_video = 2,
	nw_service_class_interactive_voice = 3,
	nw_service_class_responsive_data = 4,
	nw_service_class_signaling = 5,
} nw_service_class_t;

typedef enum {
	nw_multipath_service_disabled = 0,
	nw_multipath_service_handover = 1,
	nw_multipath_service_interactive = 2,
	nw_multipath_service_aggregate = 3,
} nw_multipath_service_t;

typedef enum {
	nw_parameters_expired_dns_behavior_default = 0,
	nw_parameters_expired_dns_behavior_allow = 1,
	nw_parameters_expired_dns_behavior_prohibit = 2,
} nw_parameters_expired_dns_behavior_t;

typedef void (^nw_connection_boolean_event_handler_t)(bool value);
typedef void (^nw_connection_path_event_handler_t)(nw_path_t path);
typedef void (^nw_connection_receive_completion_t)(dispatch_data_t _Nullable content,
	nw_content_context_t _Nullable context, bool is_complete, nw_error_t _Nullable error);
typedef void (^nw_connection_send_completion_t)(nw_error_t _Nullable error);
typedef void (^nw_connection_state_changed_handler_t)(nw_connection_state_t state, nw_error_t _Nullable error);
typedef void (^nw_listener_advertised_endpoint_changed_handler_t)(nw_endpoint_t advertised_endpoint, bool added);
typedef void (^nw_listener_new_connection_handler_t)(nw_connection_t connection);
typedef void (^nw_listener_state_changed_handler_t)(nw_listener_state_t state, nw_error_t _Nullable error);
typedef bool (^nw_parameters_iterate_interfaces_block_t)(nw_interface_t interface);
typedef bool (^nw_parameters_iterate_interface_types_block_t)(nw_interface_type_t interface_type);
typedef bool (^nw_path_enumerate_interfaces_block_t)(nw_interface_t interface);
typedef void (^nw_path_monitor_update_handler_t)(nw_path_t path);
typedef void (^nw_protocol_stack_iterate_protocols_block_t)(nw_protocol_options_t protocol);

// Advertise descriptors
nw_advertise_descriptor_t _Nullable nw_advertise_descriptor_create_bonjour_service(const char *_Nullable name,
	const char *type, const char *_Nullable domain);
void nw_advertise_descriptor_set_txt_record(nw_advertise_descriptor_t advertise_descriptor,
	const void *_Nullable txt_record, size_t txt_length);

// Connections
nw_connection_t nw_connection_create(nw_endpoint_t endpoint, nw_parameters_t parameters);
void nw_connection_set_queue(nw_connection_t connection, dispatch_queue_t queue);
void nw_connection_start(nw_connection_t connection);
void nw_connection_restart(nw_connection_t connection);
void nw_connection_cancel(nw_connection_t connection);
void nw_connection_force_cancel(nw_connection_t connection);
void nw_connection_cancel_current_endpoint(nw_connection_t connection);
void nw_connection_batch(nw_connection_t connection, NS_NOESCAPE dispatch_block_t batch_block);
nw_endpoint_t nw_connection_copy_endpoint(nw_connection_t connection);
nw_path_t _Nullable nw_connection_copy_current_path(nw_connection_t connection);
nw_protocol_metadata_t _Nullable nw_connection_copy_protocol_metadata(nw_connection_t connection,
	nw_protocol_definition_t definition);
uint32_t nw_connection_get_maximum_datagram_size(nw_connection_t connection);
void nw_connection_set_state_changed_handler(nw_connection_t connection,
	nw_connection_state_changed_handler_t _Nullable handler);
void nw_connection_set_viability_changed_handler(nw_connection_t connection,
	nw_connection_boolean_event_handler_t _Nullable handler);
void nw_connection_set_better_path_available_handler(nw_connection_t connection,
	nw_connection_boolean_event_handler_t _Nullable handler);
void nw_connection_set_path_changed_handler(nw_connection_t connection,
	nw_connection_path_event_handler_t _Nullable handler);
void nw_connection_receive(nw_connection_t connection, uint32_t minimum_incomplete_length,
	uint32_t maximum_length, nw_connection_receive_completion_t completion);
void nw_connection_receive_message(nw_connection_t connection, nw_connection_receive_completion_t completion);
void nw_connection_send(nw_connection_t connection, dispatch_data_t _Nullable content,
	nw_content_context_t context, bool is_complete, nw_connection_send_completion_t completion);

// Content contexts
nw_content_context_t nw_content_context_create(const char *context_identifier);
const char *nw_content_context_get_identifier(nw_content_context_t context);
bool nw_content_context_get_is_final(nw_content_context_t context);
void nw_content_context_set_is_final(nw_content_context_t context, bool is_final);
void nw_content_context_set_antecedent(nw_content_context_t context, nw_content_context_t _Nullable antecedent_context);
void nw_content_context_set_expiration_milliseconds(nw_content_context_t context, uint64_t expiration_milliseconds);
void nw_content_context_set_relative_priority(nw_content_context_t context, double relative_priority);
void nw_content_context_set_metadata_for_protocol(nw_content_context_t context, nw_protocol_metadata_t protocol_metadata);
nw_protocol_metadata_t _Nullable nw_content_context_copy_protocol_metadata(nw_content_context_t context,
	nw_protocol_definition_t protocol);
void nw_content_context_foreach_protocol_metadata(nw_content_context_t context,
	void (^foreach_block)(nw_protocol_definition_t definition, nw_protocol_metadata_t metadata));

// Endpoints
nw_endpoint_t nw_endpoint_create_host(const char *hostname, const char *port);
nw_endpoint_t nw_endpoint_create_address(const struct sockaddr *address);
nw_endpoint_t nw_endpoint_create_bonjour_service(const char *name, const char *type, const char *domain);
nw_endpoint_type_t nw_endpoint_get_type(nw_endpoint_t endpoint);
const char *nw_endpoint_get_hostname(nw_endpoint_t endpoint);
uint16_t nw_endpoint_get_port(nw_endpoint_t endpoint);
const struct sockaddr *nw_endpoint_get_address(nw_endpoint_t endpoint);
char *nw_endpoint_copy_address_string(nw_endpoint_t endpoint);
const char *nw_endpoint_get_bonjour_service_name(nw_endpoint_t endpoint);
const char *nw_endpoint_get_bonjour_service_type(nw_endpoint_t endpoint);
const char *nw_endpoint_get_bonjour_service_domain(nw_endpoint_t endpoint);

// Errors
nw_error_domain_t nw_error_get_error_domain(nw_error_t error);
int nw_error_get_error_code(nw_error_t error);

// Interfaces
nw_interface_type_t nw_interface_get_type(nw_interface_t interface);
const char *nw_interface_get_name(nw_interface_t interface);
uint32_t nw_interface_get_index(nw_interface_t interface);

// IP
nw_protocol_definition_t nw_protocol_copy_ip_definition(void);
nw_protocol_metadata_t nw_ip_create_metadata(void);
nw_ip_ecn_flag_t nw_ip_metadata_get_ecn_flag(nw_protocol_metadata_t metadata);
void nw_ip_metadata_set_ecn_flag(nw_protocol_metadata_t metadata, nw_ip_ecn_flag_t ecn_flag);
nw_service_class_t nw_ip_metadata_get_service_class(nw_protocol_metadata_t metadata);
void nw_ip_metadata_set_service_class(nw_protocol_metadata_t metadata, nw_service_class_t service_class);
uint64_t nw_ip_metadata_get_receive_time(nw_protocol_metadata_t metadata);
void nw_ip_options_set_version(nw_protocol_options_t options, nw_ip_version_t version);
void nw_ip_options_set_hop_limit(nw_protocol_options_t options, uint8_t hop_limit);
void nw_ip_options_set_use_minimum_mtu(nw_protocol_options_t options, bool use_minimum_mtu);
void nw_ip_options_set_disable_fragmentation(nw_protocol_options_t options, bool disable_fragmentation);
void nw_ip_options_set_calculate_receive_time(nw_protocol_options_t options, bool calculate_receive_time);

// Listeners
nw_listener_t _Nullable nw_listener_create(nw_parameters_t parameters);
nw_listener_t _Nullable nw_listener_create_with_port(const char *port, nw_parameters_t parameters);
nw_listener_t _Nullable nw_listener_create_with_connection(nw_connection_t connection, nw_parameters_t parameters);
void nw_listener_set_queue(nw_listener_t listener, dispatch_queue_t queue);
void nw_listener_start(nw_listener_t listener);
void nw_listener_cancel(nw_listener_t listener);
uint16_t nw_listener_get_port(nw_listener_t listener);
void nw_listener_set_state_changed_handler(nw_listener_t listener, nw_listener_state_changed_handler_t _Nullable handler);
void nw_listener_set_new_connection_handler(nw_listener_t listener, nw_listener_new_connection_handler_t _Nullable handler);
void nw_listener_set_advertise_descriptor(nw_listener_t listener, nw_advertise_descriptor_t _Nullable advertise_descriptor);
void nw_listener_set_advertised_endpoint_changed_handler(nw_listener_t listener,
	nw_listener_advertised_endpoint_changed_handler_t _Nullable handler);

// Parameters
nw_parameters_t nw_parameters_create(void);
nw_parameters_t nw_parameters_copy(nw_parameters_t parameters);
nw_protocol_stack_t nw_parameters_copy_default_protocol_stack(nw_parameters_t parameters);
nw_endpoint_t _Nullable nw_parameters_copy_local_endpoint(nw_parameters_t parameters);
void nw_parameters_set_local_endpoint(nw_parameters_t parameters, nw_endpoint_t _Nullable local_endpoint);
nw_interface_t _Nullable nw_parameters_copy_required_interface(nw_parameters_t parameters);
void nw_parameters_require_interface(nw_parameters_t parameters, nw_interface_t _Nullable interface);
nw_interface_type_t nw_parameters_get_required_interface_type(nw_parameters_t parameters);
void nw_parameters_set_required_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type);
void nw_parameters_prohibit_interface(nw_parameters_t parameters, nw_interface_t interface);
void nw_parameters_clear_prohibited_interfaces(nw_parameters_t parameters);
void nw_parameters_iterate_prohibited_interfaces(nw_parameters_t parameters,
	NS_NOESCAPE nw_parameters_iterate_interfaces_block_t iterate_block);
void nw_parameters_prohibit_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type);
void nw_parameters_clear_prohibited_interface_types(nw_parameters_t parameters);
void nw_parameters_iterate_prohibited_interface_types(nw_parameters_t parameters,
	NS_NOESCAPE nw_parameters_iterate_interface_types_block_t iterate_block);
bool nw_parameters_get_prohibit_expensive(nw_parameters_t parameters);
void nw_parameters_set_prohibit_expensive(nw_parameters_t parameters, bool prohibit_expensive);
bool nw_parameters_get_reuse_local_address(nw_parameters_t parameters);
void nw_parameters_set_reuse_local_address(nw_parameters_t parameters, bool reuse_local_address);
bool nw_parameters_get_local_only(nw_parameters_t parameters);
void nw_parameters_set_local_only(nw_parameters_t parameters, bool local_only);
bool nw_parameters_get_prefer_no_proxy(nw_parameters_t parameters);
void nw_parameters_set_prefer_no_proxy(nw_parameters_t parameters, bool prefer_no_proxy);
bool nw_parameters_get_include_peer_to_peer(nw_parameters_t parameters);
void nw_parameters_set_include_peer_to_peer(nw_parameters_t parameters, bool include_peer_to_peer);
bool nw_parameters_get_fast_open_enabled(nw_parameters_t parameters);
void nw_parameters_set_fast_open_enabled(nw_parameters_t parameters, bool fast_open_enabled);
nw_service_class_t nw_parameters_get_service_class(nw_parameters_t parameters);
void nw_parameters_set_service_class(nw_parameters_t parameters, nw_service_class_t service_class);
nw_multipath_service_t nw_parameters_get_multipath_service(nw_parameters_t parameters);
void nw_parameters_set_multipath_service(nw_parameters_t parameters, nw_multipath_service_t multipath_service);
nw_parameters_expired_dns_behavior_t nw_parameters_get_expired_dns_behavior(nw_parameters_t parameters);
void nw_parameters_set_expired_dns_behavior(nw_parameters_t parameters,
	nw_parameters_expired_dns_behavior_t expired_dns_behavior);

// Paths
nw_path_status_t nw_path_get_status(nw_path_t path);
bool nw_path_is_expensive(nw_path_t path);
bool nw_path_is_constrained(nw_path_t path);
bool nw_path_has_ipv4(nw_path_t path);
bool nw_path_has_ipv6(nw_path_t path);
bool nw_path_has_dns(nw_path_t path);
bool nw_path_uses_interface_type(nw_path_t path, nw_interface_type_t interface_type);
bool nw_path_is_equal(nw_path_t path, nw_path_t other_path);
void nw_path_enumerate_interfaces(nw_path_t path, NS_NOESCAPE nw_path_enumerate_interfaces_block_t enumerate_block);
nw_endpoint_t _Nullable nw_path_copy_effective_local_endpoint(nw_path_t path);
nw_endpoint_t _Nullable nw_path_copy_effective_remote_endpoint(nw_path_t path);

// Path monitors
nw_path_monitor_t nw_path_monitor_create(void);
nw_path_monitor_t nw_path_monitor_create_with_type(nw_interface_type_t required_interface_type);
void nw_path_monitor_prohibit_interface_type(nw_path_monitor_t monitor, nw_interface_type_t interface_type);
void nw_path_monitor_set_queue(nw_path_monitor_t monitor, dispatch_queue_t queue);
void nw_path_monitor_set_update_handler(nw_path_monitor_t monitor, nw_path_monitor_update_handler_t update_handler);
void nw_path_monitor_start(nw_path_monitor_t monitor);
void nw_path_monitor_cancel(nw_path_monitor_t monitor);

// Protocols
bool nw_protocol_definition_is_equal(nw_protocol_definition_t definition1, nw_protocol_definition_t definition2);
nw_protocol_definition_t nw_protocol_options_copy_definition(nw_protocol_options_t options);
bool nw_protocol_metadata_is_ip(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_tcp(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_tls(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_udp(nw_protocol_metadata_t metadata);
void nw_protocol_stack_prepend_application_protocol(nw_protocol_stack_t stack, nw_protocol_options_t protocol);
void nw_protocol_stack_clear_application_protocols(nw_protocol_stack_t stack);
void nw_protocol_stack_iterate_application_protocols(nw_protocol_stack_t stack,
	NS_NOESCAPE nw_protocol_stack_iterate_protocols_block_t iterate_block);
nw_protocol_options_t _Nullable nw_protocol_stack_copy_transport_protocol(nw_protocol_stack_t stack);
void nw_protocol_stack_set_transport_protocol(nw_protocol_stack_t stack, nw_protocol_options_t protocol);
nw_protocol_options_t _Nullable nw_protocol_stack_copy_internet_protocol(nw_protocol_stack_t stack);

// TCP
nw_protocol_definition_t nw_protocol_copy_tcp_definition(void);
nw_protocol_options_t nw_tcp_create_options(void);
void nw_tcp_options_set_no_delay(nw_protocol_options_t options, bool no_delay);
void nw_tcp_options_set_no_push(nw_protocol_options_t options, bool no_push);
void nw_tcp_options_set_no_options(nw_protocol_options_t options, bool no_options);
void nw_tcp_options_set_enable_keepalive(nw_protocol_options_t options, bool enable_keepalive);
void nw_tcp_options_set_keepalive_count(nw_protocol_options_t options, uint32_t keepalive_count);
void nw_tcp_options_set_keepalive_idle_time(nw_protocol_options_t options, uint32_t keepalive_idle_time);
void nw_tcp_options_set_keepalive_interval(nw_protocol_options_t options, uint32_t keepalive_interval);
void nw_tcp_options_set_maximum_segment_size(nw_protocol_options_t options, uint32_t maximum_segment_size);
void nw_tcp_options_set_connection_timeout(nw_protocol_options_t options, uint32_t connection_timeout);
void nw_tcp_options_set_persist_timeout(nw_protocol_options_t options, uint32_t persist_timeout);
void nw_tcp_options_set_retransmit_connection_drop_time(nw_protocol_options_t options,
	uint32_t retransmit_connection_drop_time);
void nw_tcp_options_set_retransmit_fin_drop(nw_protocol_options_t options, bool retransmit_fin_drop);
void nw_tcp_options_set_disable_ack_stretching(nw_protocol_options_t options, bool disable_ack_stretching);
void nw_tcp_options_set_enable_fast_open(nw_protocol_options_t options, bool enable_fast_open);
void nw_tcp_options_set_disable_ecn(nw_protocol_options_t options, bool disable_ecn);
uint32_t nw_tcp_get_available_receive_buffer(nw_protocol_metadata_t metadata);
uint32_t nw_tcp_get_available_send_buffer(nw_protocol_metadata_t metadata);

// TLS
nw_protocol_definition_t nw_protocol_copy_tls_definition(void);
nw_protocol_options_t nw_tls_create_options(void);
sec_protocol_options_t nw_tls_copy_sec_protocol_options(nw_protocol_options_t options);
sec_protocol_metadata_t nw_tls_copy_sec_protocol_metadata(nw_protocol_metadata_t metadata);

// UDP
nw_protocol_definition_t nw_protocol_copy_udp_definition(void);
nw_protocol_options_t nw_udp_create_options(void);
void nw_udp_options_set_prefer_no_checksum(nw_protocol_options_t options, bool prefer_no_checksum);
nw_protocol_metadata_t nw_udp_create_metadata(void);

// Not documented: libnetwork exports that the 5.2.2 overlay calls.
nw_interface_t _Nullable nw_interface_create_with_index(uint32_t interface_index);
nw_interface_t _Nullable nw_interface_create_with_name(const char *interface_name);
nw_interface_t _Nullable nw_endpoint_copy_interface(nw_endpoint_t endpoint);
void nw_endpoint_set_interface(nw_endpoint_t endpoint, nw_interface_t _Nullable interface);
nw_endpoint_t _Nullable nw_endpoint_create_unix(const char *path);
const char *nwlog_get_string_for_dns_service_error(int32_t error);

NS_ASSUME_NONNULL_END

#endif
