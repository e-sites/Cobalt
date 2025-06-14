# Changelog Cobalt

## v10.1.5 (02-06-2025)
- Redirect Authorization headers

## v10.1.3 (24-05-2024)
- `isRequesting`

## v10.1.2 (24-05-2024)
- `allowConcurrentCalls`

## v10.1.1 (24-05-2024)
- `tryMap`

## v10.1.0 (23-05-2024)
- Created `generateURLRequest` in `CobaltRequest`

## v10.0.3 (22-04-2024)
- Improved 'map(to:)'

## v10.0.2 (08-04-2024)
- AccessToken public functions

## v10.0.1 (16-02-2023)
- Fixed stubbing

## v10.0.0 (15-02-2023)
- Use `DebugMasking` dependency

## v9.0.2 (08-02-2023)
- Fixed requestID logging

## v9.0.0 (02-11-2022)
- Refactored a bunch of stuff

## v8.2.0 (02-11-2022)
- Added stubbing

## v8.1.5 (14-10-2022)
- Mask CobaltError response description

## v8.1.4 (14-10-2022)
- Fixed helpers

## v8.1.3 (14-10-2022)
- Added array support for logging options

## v8.1.2 (05-07-2022)
- Fixed a bug that loses response data in underlying errors

## v8.1.1 (28-06-2022)
- Half masked email addresses

## v8.1.0 (27-06-2022)
- Added headers logging options

## v8.0.6 (13-05-2022)
- Fixed a bug where the queue was not handled when a auth error occurred

## v8.0.5 (10-05-2022)
- Added `refreshTokenPath` to config

## v8.0.4 (08-03-2022)
- Removed timing

## v8.0.3 (15-02-2022)
- Fixed `isIgnoreAll`

## v8.0.2 (05-01-2022)
- `String` is now a `CobaltResponse` type
- Define key when parsing an array or dictionary

## v8.0.1 (28-12-2021)
- Added timing

## v8.0.0 (09-07-2021)
- Replaced RxSwift with Combine
- Removed SwiftyJSON dependency

## v7.3.3 (25-01-2022)
- Preventing concurrency when refreshing the access token simultaneously for multiple requests

## v7.3.2 (22-12-2021)
- Added `cachePolicy` to requests, which sets `URLRequest.cachePolicy`

## v7.3.1 (30-09-2021)
- Added `session` to define your custom Alamofire Sessions

## v7.3.0 (16-08-2021)
- Added option for PKCE to authorization configuration
- Added ability to create AuthorizationCodeRequest to simplify authorization_code grant type

## v7.2.0 (17-03-2021)
- Added raw body parameter to Request

## v7.1.4 (01-03-2021)
- RxSwift update to v6

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
- `Cobalt` -> `CobaltClient`

## v5.1.0 (12-07-2018)
- Store `AccessToken` in individual keychains per host, this way you can use multiple `Cobalt` isntances for multiple API's.

## v5.0.0 (11-07-2018)
- Initial public release
