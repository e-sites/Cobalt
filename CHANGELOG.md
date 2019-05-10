# Changelog Cobalt

## v5.8.2 (10-05-2019)
- Use Carthage for build pipeline instead of accio

## v5.8.1 (10-05-2019)
- Improved accio

## v5.8.0 (05-05-2019)
- Swift 5.0
- Accio compatible

## v5.7.0 (21-11-2018)
- Use `Config.clientAuthorization` to allow `requestBody` client authentication instead of default through the `.basicHeader`.

## v5.6.1 (20-11-2018)
- Make oauth2 endpoint path configurable

## v5.6.0 (25-10-2018)
- Start / finish request for metrics

## v5.5.1 (24-10-2018)
- Allow masking of access-, and refresh-tokens

## v5.5.0 (05-09-2018)
- Make `AccessToken` public

## v5.4.0 (05-09-2018)
- Update to Swift 4.2 / Xcode10

## v5.3.2 (05-09-2018)
- Allow nested objects in `parametersLoggingOptions`

## v5.3.1 (04-09-2018)
- Fixed a bug where `parametersLoggingOptions` would not mask the password field by default.

## v5.3.0 (30-08-2018)
- Add `parametersLoggingOptions` to control the way parameters are logged in the request

## v5.2.5 (24-08-2018)
- Improved `AccessToken` local (keychain) storage

## v5.2.4 (17-08-2018)
- Carthage compatible

## v5.2.3 (27-07-2018)
- Fixed a bug with unitialized KeyChain

## v5.2.2 (20-07-2018)
- Added `log(_:)` and `info(_:)` to `Logger` protocol

## v5.2.1 (19-07-2018)
- Removed `SwiftyUserDefaults` dependency

## v5.2.0 (16-07-2018)
- `Cobalt` -> `Cobalt.Client`

## v5.1.0 (12-07-2018)
- Store `AccessToken` in individual keychains per host, this way you can use multiple `Cobalt` isntances for multiple API's.

## v5.0.0 (11-07-2018)
- Initial public release