# Changelog Cobalt

## v7.2.0 (08-01-2021)
- Added option for PKCE to authorization configuration
- Added ability to create AuthorizationCodeRequest to simplify authorization_code grant type

## v7.1.3 (10-12-2020)
- Shortened logging option with no fallbacks

## v7.1.2 (13-11-2020)
- authorization_code also needs refresh_token to refresh

## v7.1.1 (06-11-2020)
- authorization_code grant_type

## v7.1.0 (05-11-2020)
- Added authentication host
- Better structure for the `Config` class

## v7.0.9 (18-09-2020)
- Mask parameters in Request debugDescription

## v7.0.8 (03-09-2020)
- Store `OAuthenticationGrantType`

## v7.0.7 (03-09-2020)
- Added request to the Error (for logging purposes)

## v7.0.6 (18-08-2020)
- Fixed logging for non dictionary json responses

## v7.0.5 (17-08-2020)
- Fixed a bug where an error was thrown when no authentication is required

## v7.0.4 (16-07-2020)
- LoggingOption "*" ignore available

## v7.0.2 (16-07-2020)
- Minimum requirement: 10.0
- Updated Alamofire to v5

## v7.0.1 (16-07-2020)
- CocoaPods

## v7.0.0 (13-07-2020)
- Use swift-log as logging framework

## v6.0.1 (22-06-2020)
- Fixed a bug where request would be send twice

## v6.0.0 (22-06-2020)
- Replaced Promises with RxSwift

## v5.10.7 (13-05-2020)
- `open` login

## v5.10.6 (11-05-2020)
- Fixed a bug with custom headers

## v5.10.5 (17-04-2020)
- Fixed bug in logging request options for dictionaries

## v5.10.3 (15-11-2019)
- Make `request` open

## v5.10.2 (24-10-2019)
- iso8601 default mapping date

## v5.10.1 (02-10-2019)
- Split up caching and core for SwiftPM

## v5.10.0 (23-08-2019)
- Make requests cacheable
 
## v5.9.5 (30-06-2019)
- Adding json to underlying error when present

## v5.9.4 (20-06-2019)
- Adding underlying error instead of unknown error 

## v5.9.3 (19-06-2019)
- Bugfix manual auth provider

## v5.9.2 (19-06-2019)
- Bugfix manual auth provider

## v5.9.1 (19-06-2019)
- Provide a way to store the login state when logging in manually

## v5.9.0 (31-05-2019)
- Refactored request / response logging

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
