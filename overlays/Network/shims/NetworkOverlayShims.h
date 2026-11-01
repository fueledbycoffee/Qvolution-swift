// Helpers the Network Swift overlay sources call through `import _SwiftNetworkOverlayShims`,
// written for Darling (the swift repository's NetworkOverlayShims.h is not vendored here).
// The three content contexts are the constants Darling's libnetwork exports
// (src/external/libnetwork/src/nw/connection.m). Darling's libnetwork has no idempotent-content
// marker, so an idempotent send is an ordinary send whose completion does nothing. Data and
// dispatch data are converted with the documented dispatch_data_create and dispatch_data_apply.
#ifndef DARLING_NETWORK_OVERLAY_SHIMS_H
#define DARLING_NETWORK_OVERLAY_SHIMS_H

#import <Foundation/Foundation.h>
#include "DarlingNetwork.h"

NS_ASSUME_NONNULL_BEGIN

extern const nw_content_context_t NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT;
extern const nw_content_context_t NW_CONNECTION_FINAL_MESSAGE_CONTEXT;
extern const nw_content_context_t NW_CONNECTION_DEFAULT_STREAM_CONTEXT;

static inline nw_content_context_t _swift_nw_content_context_default_message(void) {
	return NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT;
}

static inline nw_content_context_t _swift_nw_content_context_final_message(void) {
	return NW_CONNECTION_FINAL_MESSAGE_CONTEXT;
}

static inline nw_content_context_t _swift_nw_content_context_default_stream(void) {
	return NW_CONNECTION_DEFAULT_STREAM_CONTEXT;
}

static inline void _swift_nw_connection_send(nw_connection_t connection, dispatch_data_t _Nullable content,
		nw_content_context_t context, bool is_complete, nw_connection_send_completion_t completion) {
	nw_connection_send(connection, content, context, is_complete, completion);
}

static inline void _swift_nw_connection_send_idempotent(nw_connection_t connection,
		dispatch_data_t _Nullable content, nw_content_context_t context, bool is_complete) {
	nw_connection_send(connection, content, context, is_complete, ^(nw_error_t _Nullable error) {});
}

static inline dispatch_data_t _Nullable NWCreateDispatchDataFromNSData(NSData *_Nullable data) {
	if (data == nil)
		return nil;
	return dispatch_data_create(data.bytes, data.length, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
}

static inline NSData *_Nullable NWCreateNSDataFromDispatchData(dispatch_data_t _Nullable data) {
	if (data == nil)
		return nil;
	NSMutableData *result = [NSMutableData dataWithCapacity:dispatch_data_get_size(data)];
	dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
		[result appendBytes:buffer length:size];
		return true;
	});
	return result;
}

NS_ASSUME_NONNULL_END

#endif
