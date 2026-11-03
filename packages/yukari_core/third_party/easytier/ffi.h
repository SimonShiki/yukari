#ifndef EASYTIER_FFI_H
#define EASYTIER_FFI_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

/**
 * A key/value pair used by list_instance and collect_network_infos.
 *
 * The caller allocates the array of pairs; the native side only fills in the
 * pointers, which stay valid until the next call into the same API family.
 */
typedef struct KeyValuePair {
    /** NUL-terminated UTF-8 key string owned by the native library. */
    const char *key;
    /** NUL-terminated UTF-8 value string owned by the native library. */
    const char *value;
} KeyValuePair;

/**
 * Callback invoked by the config server client when a server event arrives.
 *
 * event_json is a NUL-terminated UTF-8 JSON string that is only valid for the
 * duration of the callback; copy it if it must outlive the call. user_data is
 * the pointer passed to start_config_server_client, passed through unchanged.
 * The callback runs on an EasyTier internal thread, so it must not block.
 */
typedef void (*ConfigServerEventCallback)(const char *event_json, void *user_data);

/**
 * A socket address in the data-plane ABI (v3 accepts IPv4 only).
 *
 * All integer fields use native byte order; address bytes use network order.
 */
typedef struct DataPlaneSocketAddr {
    /** Address family; currently always 4 (IPv4). */
    uint16_t family;
    /** Port number in native byte order. */
    uint16_t port;
    /** Raw address bytes in network order; IPv4 uses the first four bytes. */
    uint8_t address[16];
} DataPlaneSocketAddr;

/**
 * One terminal notification produced by a submitted data-plane operation.
 *
 * Descriptors are obtained from data_plane_completion_drain. Draining makes
 * the typed result available but does not consume it; a *_result_take call
 * consumes it exactly once.
 */
typedef struct DataPlaneCompletion {
    /** Operation id that finished, as returned by a submit call. */
    uint64_t operation_id;
    /** Operation kind: 1 TCP connect, 2 TCP bind, 3 TCP accept, 4 TCP read,
     * 5 TCP write, 6 UDP bind, 7 UDP receive, 8 UDP send. */
    uint16_t operation_kind;
    /** Terminal status: 0 on success, otherwise a negative
     *  DataPlaneErrorKind value. */
    uint16_t status;
} DataPlaneCompletion;

/** Deadline direction selecting the read side of a resource. */
#define DATA_PLANE_DEADLINE_READ 1u
/** Deadline direction selecting the write side of a resource. */
#define DATA_PLANE_DEADLINE_WRITE 2u

/**
 * Parse and validate a config string without starting any instance.
 *
 * cfg_str must be a non-NULL NUL-terminated UTF-8 config string that stays
 * alive for the duration of the call. Returns 0 on success. On failure
 * (non-zero), call get_error_msg on the same thread for the detail.
 */
int parse_config(const char *cfg_str);

/**
 * Start a network instance from a config string and block until it exits.
 *
 * cfg_str must be a non-NULL NUL-terminated UTF-8 config string that stays
 * alive for the duration of the call. This function returns only after the
 * instance stops. Returns 0 on clean exit; on failure (non-zero), call
 * get_error_msg on the same thread for the detail.
 */
int run_network_instance(const char *cfg_str);

/**
 * Increase the retain count of each named instance, keeping them alive.
 *
 * inst_names points to an array of length NUL-terminated UTF-8 instance-name
 * strings; the array and the strings must stay alive for the duration of the
 * call. An instance runs until its retain count drops back to zero. Returns 0
 * on success; on failure (non-zero), call get_error_msg on the same thread.
 */
int retain_network_instance(const char *const *inst_names, size_t length);

/**
 * Decrease the retain count of each named instance; at zero the instance stops.
 *
 * inst_names points to an array of length NUL-terminated UTF-8 instance-name
 * strings; the array and the strings must stay alive for the duration of the
 * call. Returns 0 on success; on failure (non-zero), call get_error_msg on
 * the same thread.
 */
int delete_network_instance(const char *const *inst_names, size_t length);

/**
 * List running instances as name/JSON-config pairs.
 *
 * infos must point to a caller-allocated array of at least max_length
 * KeyValuePair elements; the entries are filled with pointers owned by the
 * native library and valid until the next list-style call. Returns the number
 * of pairs written (clamped to max_length) on success; on failure (negative),
 * call get_error_msg on the same thread.
 */
int list_instance(KeyValuePair *infos, size_t max_length);

/**
 * Collect peer/network information of running instances as name/JSON pairs.
 *
 * infos must point to a caller-allocated array of at least max_length
 * KeyValuePair elements; the entries are filled with pointers owned by the
 * native library and valid until the next list-style call. Returns the number
 * of pairs written (clamped to max_length) on success; on failure (negative),
 * call get_error_msg on the same thread.
 */
int collect_network_infos(KeyValuePair *infos, size_t max_length);

/**
 * Attach a tun file descriptor to a running instance.
 *
 * inst_name must be a non-NULL NUL-terminated UTF-8 instance name alive for
 * the duration of the call. fd is a platform tun device descriptor whose
 * ownership transfers to the instance on success. Returns 0 on success; on
 * failure (non-zero), call get_error_msg on the same thread.
 */
int set_tun_fd(const char *inst_name, int fd);

/**
 * Invoke a JSON-RPC method on a running instance and return the response.
 *
 * service_name, method_name, and domain_name must be non-NULL NUL-terminated
 * UTF-8 strings alive for the duration of the call; payload_json is the
 * request body as UTF-8 JSON, or NULL when the method takes no payload.
 * out_response_json must be non-NULL: on success it receives a newly
 * allocated NUL-terminated UTF-8 JSON response that the caller must release
 * with free_string. Returns 0 on success; on failure (non-zero), the output
 * pointer is untouched and get_error_msg (same thread) gives the detail.
 */
int call_json_rpc(const char *service_name, const char *method_name,
                  const char *domain_name, const char *payload_json,
                  const char **out_response_json);

/**
 * Start the singleton config server client and register an event callback.
 *
 * config_server_url, hostname, and machine_id must be non-NULL NUL-terminated
 * UTF-8 strings alive for the duration of the call. secure_mode enables TLS
 * verification for the connection. callback is invoked for every server
 * event; user_data is passed through to it unchanged. Returns 0 on success;
 * on failure (non-zero), call get_error_msg on the same thread.
 */
int start_config_server_client(const char *config_server_url, const char *hostname,
                               const char *machine_id, bool secure_mode,
                               ConfigServerEventCallback callback, void *user_data);

/**
 * Stop the config server client started by start_config_server_client.
 *
 * Returns 0 on success; on failure (non-zero), call get_error_msg on the
 * same thread.
 */
int stop_config_server_client(void);

/**
 * Report whether the config server client currently holds a connected session.
 *
 * Returns 1 when connected, 0 otherwise. This query cannot fail.
 */
int is_config_server_client_connected(void);

/**
 * Take the last error message recorded on the calling thread.
 *
 * out must be non-NULL. It receives a newly allocated NUL-terminated UTF-8
 * string that the caller must release with free_string, or NULL when no
 * error was recorded. Error messages are thread-local: read the error on the
 * same thread that made the failing call.
 */
void get_error_msg(const char **out);

/**
 * Release a string previously returned by get_error_msg or call_json_rpc.
 *
 * Passing NULL is a no-op. Each string must be freed exactly once.
 */
void free_string(const char *s);

/**
 * Open a data-plane session bound to one running EasyTier instance.
 *
 * inst_name must be a non-NULL NUL-terminated UTF-8 instance name alive for
 * the duration of the call. out_session must be non-NULL and receives the
 * new session handle on success. At most one native session may be open per
 * instance. Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_session_open(const char *inst_name, uint64_t *out_session);

/**
 * Close a data-plane session, cancelling and discarding its outstanding
 * operations and resources, and waking any thread blocked in
 * data_plane_completion_wait for this session.
 *
 * session must be a live handle from data_plane_session_open. Returns 0 on
 * success or a negative DataPlaneErrorKind value.
 */
int data_plane_session_close(uint64_t session);

/**
 * Submit a TCP connect to a peer address through the session's instance.
 *
 * peer_addr is copied before the call returns. timeout_ms bounds the
 * operation from the moment submission is accepted; UINT64_MAX means no
 * deadline. out_operation must be non-NULL and receives the new operation id
 * on success. Completes as operation kind 1; on success take the result with
 * data_plane_tcp_connect_result_take. Returns 0 on success or a negative
 * DataPlaneErrorKind value.
 */
int data_plane_tcp_connect_submit(uint64_t session, DataPlaneSocketAddr peer_addr,
                                   uint64_t timeout_ms, uint64_t *out_operation);

/**
 * Submit a TCP listener bind on a local port within the session.
 *
 * timeout_ms bounds the bind from the moment submission is accepted;
 * UINT64_MAX means no deadline. out_operation must be non-NULL and receives
 * the new operation id on success. Completes as operation kind 2; take the
 * result with data_plane_tcp_bind_result_take. Returns 0 on success or a
 * negative DataPlaneErrorKind value.
 */
int data_plane_tcp_bind_submit(uint64_t session, uint16_t local_port,
                               uint64_t timeout_ms, uint64_t *out_operation);

/**
 * Submit an accept operation on a TCP listener obtained earlier.
 *
 * listener must be a live stream-handle resource from a bind result of the
 * same session. timeout_ms bounds the accept from the moment submission is
 * accepted; UINT64_MAX means no deadline. out_operation must be non-NULL and
 * receives the new operation id on success. Completes as operation kind 3;
 * take the result with data_plane_tcp_accept_result_take. Returns 0 on
 * success or a negative DataPlaneErrorKind value.
 */
int data_plane_tcp_accept_submit(uint64_t session, uint64_t listener,
                                 uint64_t timeout_ms, uint64_t *out_operation);

/**
 * Submit a TCP read of at most max_len bytes on an open stream.
 *
 * stream must be a live stream-handle resource from a connect or accept
 * result of the same session. The payload becomes readable through
 * data_plane_tcp_read_result_take once the operation completes. Repeated
 * reads require a fresh submit for each completion. Completes as operation
 * kind 4. Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_tcp_read_submit(uint64_t session, uint64_t stream,
                               uint32_t max_len, uint64_t *out_operation);

/**
 * Submit a TCP write; the bytes are copied before this call returns.
 *
 * data must point to len readable bytes alive for the duration of the call;
 * len == 0 writes nothing. stream must be a live stream-handle resource of
 * the same session. Completes as operation kind 5; take the number of bytes
 * written with data_plane_tcp_write_result_take. Returns 0 on success or a
 * negative DataPlaneErrorKind value.
 */
int data_plane_tcp_write_submit(uint64_t session, uint64_t stream,
                                const uint8_t *data, uint32_t len, uint64_t *out_operation);

/**
 * Submit a UDP socket bind on a local port within the session.
 *
 * timeout_ms bounds the bind from the moment submission is accepted;
 * UINT64_MAX means no deadline. out_operation must be non-NULL and receives
 * the new operation id on success. Completes as operation kind 6; take the
 * result with data_plane_udp_bind_result_take. Returns 0 on success or a
 * negative DataPlaneErrorKind value.
 */
int data_plane_udp_bind_submit(uint64_t session, uint16_t local_port,
                               uint64_t timeout_ms, uint64_t *out_operation);

/**
 * Submit a UDP receive of at most max_len bytes on a bound socket.
 *
 * socket must be a live socket-handle resource from a UDP bind result of the
 * same session. The payload, source address, and truncation flag become
 * readable through data_plane_udp_receive_result_take once the operation
 * completes. Completes as operation kind 7. Returns 0 on success or a
 * negative DataPlaneErrorKind value.
 */
int data_plane_udp_receive_submit(uint64_t session, uint64_t socket,
                                  uint32_t max_len, uint64_t *out_operation);

/**
 * Submit a UDP datagram send; the bytes are copied before this call returns.
 *
 * socket must be a live socket-handle resource of the same session.
 * peer_addr is copied before the call returns. data must point to len
 * readable bytes alive for the duration of the call. Completes as operation
 * kind 8; take the number of bytes sent with
 * data_plane_udp_send_result_take. Returns 0 on success or a negative
 * DataPlaneErrorKind value.
 */
int data_plane_udp_send_submit(uint64_t session, uint64_t socket,
                               DataPlaneSocketAddr peer_addr, const uint8_t *data,
                               uint32_t len, uint64_t *out_operation);

/**
 * Replace the persistent deadline of one direction on a stream or socket.
 *
 * resource must be a live TCP stream, TCP listener, or UDP socket handle of
 * the same session. direction selects sides by bit: 1 reads, 2 writes, 3
 * both (see DATA_PLANE_DEADLINE_READ / DATA_PLANE_DEADLINE_WRITE).
 * timeout_ms is the new limit from now on; UINT64_MAX clears the deadline.
 * The change applies immediately, including to active operations, and an
 * expired deadline stays expired until replaced or cleared. Returns 0 on
 * success or a negative DataPlaneErrorKind value.
 */
int data_plane_resource_deadline_set(uint64_t session, uint64_t resource,
                                     uint32_t direction, uint64_t timeout_ms);

/**
 * Request cancellation of a submitted but not yet completed operation.
 *
 * operation must be a live operation id of the same session. A cancelled
 * operation still produces a completion descriptor carrying its terminal
 * status. Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_operation_cancel(uint64_t session, uint64_t operation);

/**
 * Release the state of a finished operation whose result is abandoned.
 *
 * Call this instead of a *_result_take when a drained result is
 * intentionally discarded. operation must be a live operation id of the same
 * session. Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_operation_free(uint64_t session, uint64_t operation);

/**
 * Close a TCP stream, TCP listener, or UDP socket resource.
 *
 * Cancels operations referencing the resource. resource must be a live
 * handle of the same session. Returns 0 on success or a negative
 * DataPlaneErrorKind value.
 */
int data_plane_resource_close(uint64_t session, uint64_t resource);

/**
 * Block until one completion is ready or the wait times out.
 *
 * timeout_ms bounds the wait; UINT64_MAX waits without deadline. Returns 1
 * when a completion is ready, 0 on timeout or when the session was closed,
 * and a negative DataPlaneErrorKind value on failure.
 */
int data_plane_completion_wait(uint64_t session, uint64_t timeout_ms);

/**
 * Drain up to capacity completion descriptors into the caller's array.
 *
 * completions must point to at least capacity writable DataPlaneCompletion
 * elements alive for the duration of the call. Draining a descriptor makes
 * its typed result available but does not consume it. Returns the number of
 * descriptors written (non-negative), or a negative DataPlaneErrorKind value
 * on failure.
 */
int data_plane_completion_drain(uint64_t session, DataPlaneCompletion *completions,
                                uint32_t capacity);

/**
 * Query the payload size of a completed TCP-read or UDP-receive operation.
 *
 * operation must be a live, drained read/receive operation id of the same
 * session. out_size must be non-NULL and receives the byte count on success.
 * Use it to size the buffer for the matching result_take call. Returns 0 on
 * success or a negative DataPlaneErrorKind value.
 */
int data_plane_result_size(uint64_t session, uint64_t operation, uint32_t *out_size);

/**
 * Consume the result of a completed TCP connect operation exactly once.
 *
 * out_stream receives the new stream handle; out_local_addr and
 * out_peer_addr, when non-NULL, receive the negotiated addresses. If the
 * operation's status was not success, the result is consumed and a negative
 * DataPlaneErrorKind value is returned. operation must belong to the same
 * session. Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_tcp_connect_result_take(uint64_t session, uint64_t operation,
                                       uint64_t *out_stream, DataPlaneSocketAddr *out_local_addr,
                                       DataPlaneSocketAddr *out_peer_addr);

/**
 * Consume the result of a completed TCP bind operation exactly once.
 *
 * out_listener receives the new listener handle; out_local_addr, when
 * non-NULL, receives the bound address. If the operation's status was not
 * success, the result is consumed and a negative DataPlaneErrorKind value is
 * returned. Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_tcp_bind_result_take(uint64_t session, uint64_t operation,
                                    uint64_t *out_listener, DataPlaneSocketAddr *out_local_addr);

/**
 * Consume the result of a completed TCP accept operation exactly once.
 *
 * out_stream receives the new stream handle for the accepted connection;
 * out_local_addr and out_peer_addr, when non-NULL, receive the connection's
 * addresses. If the operation's status was not success, the result is
 * consumed and a negative DataPlaneErrorKind value is returned. Returns 0 on
 * success or a negative DataPlaneErrorKind value.
 */
int data_plane_tcp_accept_result_take(uint64_t session, uint64_t operation,
                                      uint64_t *out_stream, DataPlaneSocketAddr *out_local_addr,
                                      DataPlaneSocketAddr *out_peer_addr);

/**
 * Consume the result of a completed TCP read operation exactly once.
 *
 * data must point to at least capacity writable bytes alive for the
 * duration of the call; capacity should cover data_plane_result_size.
 * out_len receives the number of bytes copied and out_eof, when non-NULL,
 * the end-of-stream flag. When capacity is too small, returns
 * -BufferTooSmall and leaves the result available for a later call. Returns
 * 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_tcp_read_result_take(uint64_t session, uint64_t operation,
                                    uint8_t *data, uint32_t capacity, uint32_t *out_len, bool *out_eof);

/**
 * Consume the result of a completed TCP write operation exactly once.
 *
 * out_len must be non-NULL and receives the number of bytes written. If the
 * operation's status was not success, the result is consumed and a negative
 * DataPlaneErrorKind value is returned. Returns 0 on success or a negative
 * DataPlaneErrorKind value.
 */
int data_plane_tcp_write_result_take(uint64_t session, uint64_t operation, uint32_t *out_len);

/**
 * Consume the result of a completed UDP bind operation exactly once.
 *
 * out_socket receives the new socket handle; out_local_addr, when non-NULL,
 * receives the bound address. If the operation's status was not success, the
 * result is consumed and a negative DataPlaneErrorKind value is returned.
 * Returns 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_udp_bind_result_take(uint64_t session, uint64_t operation,
                                    uint64_t *out_socket, DataPlaneSocketAddr *out_local_addr);

/**
 * Consume the result of a completed UDP receive operation exactly once.
 *
 * data must point to at least capacity writable bytes alive for the
 * duration of the call; capacity should cover data_plane_result_size.
 * out_len receives the datagram size, out_peer_addr, when non-NULL, the
 * source address, and out_truncated, when non-NULL, whether the datagram
 * exceeded the requested max_len. When capacity is too small, returns
 * -BufferTooSmall and leaves the result available for a later call. Returns
 * 0 on success or a negative DataPlaneErrorKind value.
 */
int data_plane_udp_receive_result_take(uint64_t session, uint64_t operation,
                                       uint8_t *data, uint32_t capacity, uint32_t *out_len,
                                       DataPlaneSocketAddr *out_peer_addr, bool *out_truncated);

/**
 * Consume the result of a completed UDP send operation exactly once.
 *
 * out_len must be non-NULL and receives the number of bytes sent. If the
 * operation's status was not success, the result is consumed and a negative
 * DataPlaneErrorKind value is returned. Returns 0 on success or a negative
 * DataPlaneErrorKind value.
 */
int data_plane_udp_send_result_take(uint64_t session, uint64_t operation, uint32_t *out_len);

#ifdef __cplusplus
}
#endif
#endif
