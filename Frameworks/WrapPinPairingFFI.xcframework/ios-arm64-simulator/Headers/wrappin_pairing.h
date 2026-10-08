#ifndef WRAPPIN_PAIRING_H
#define WRAPPIN_PAIRING_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WPRemotePairingSession WPRemotePairingSession;
typedef struct WPLocationSession WPLocationSession;

typedef void (*WPRemotePairingReadyCallback)(
    void *context,
    const char *service_identifier,
    uint16_t port,
    const char *const *txt_keys,
    const char *const *txt_values,
    size_t txt_count
);

typedef void (*WPRemotePairingPINCallback)(
    void *context,
    const char *pin
);

typedef struct {
    char *error_message;
    char *device_name;
    char *device_model;
    char *device_udid;
    uint8_t *pairing_record;
    size_t pairing_record_length;
    uint8_t *host_alt_irk;
    size_t host_alt_irk_length;
} WPRemotePairingResult;

typedef void (*WPLocationStartedCallback)(void *context);

// Where a location session failed. The values mirror `LocationStage` in
// src/lib.rs and are never renumbered; Swift maps them to its failure stages.
enum {
    WPLocationStageUnknown = 0,
    WPLocationStagePairingRecord = 1,
    WPLocationStageDiscovery = 2,
    WPLocationStageVpnConnection = 3,
    WPLocationStagePairVerification = 4,
    WPLocationStageTunnelCreation = 5,
    WPLocationStageTunnelConnection = 6,
    WPLocationStageTunnelSecurity = 7,
    WPLocationStageServiceDirectory = 8,
    WPLocationStageServiceHandshake = 9,
    WPLocationStageLocationService = 10,
    WPLocationStageLocationInitialWrite = 11,
    WPLocationStageLocationActiveWrite = 12,
    WPLocationStageLocationEngine = 13,
    WPLocationStageLocationRestore = 14,
    WPLocationStageCancelled = 15
};

typedef struct {
    char *error_message;
    int32_t error_stage;
    // Non-zero when the device tunnel was not reachable yet and discovery may be retried.
    int32_t error_is_recoverable;
} WPLocationResult;

WPRemotePairingSession *wp_remote_pairing_session_create(void);

void wp_remote_pairing_session_cancel(WPRemotePairingSession *session);

int32_t wp_remote_pairing_session_run(
    WPRemotePairingSession *session,
    const char *host_name,
    const char *host_model,
    WPRemotePairingReadyCallback ready_callback,
    WPRemotePairingPINCallback pin_callback,
    void *context,
    WPRemotePairingResult *result
);

void wp_remote_pairing_result_destroy(WPRemotePairingResult *result);

void wp_remote_pairing_session_destroy(WPRemotePairingSession *session);

int32_t wp_pairing_record_matches_service(
    const uint8_t *pairing_record,
    size_t pairing_record_length,
    const char *service_identifier,
    const char *auth_tag
);

WPLocationSession *wp_location_session_create(void);

void wp_location_session_cancel(WPLocationSession *session);

int32_t wp_location_session_update(
    WPLocationSession *session,
    double latitude,
    double longitude
);

int32_t wp_location_session_run(
    WPLocationSession *session,
    const uint8_t *pairing_record,
    size_t pairing_record_length,
    const char *peer_address,
    uint16_t remote_pairing_port,
    const char *service_identifier,
    const char *auth_tag,
    double latitude,
    double longitude,
    WPLocationStartedCallback started_callback,
    void *context,
    WPLocationResult *result
);

void wp_location_result_destroy(WPLocationResult *result);

void wp_location_session_destroy(WPLocationSession *session);

#ifdef __cplusplus
}
#endif

#endif
