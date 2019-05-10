# Cobalt

![Cobalt](Assets/logo.png)

Cobalt is part of the **[E-sites iOS Suite](https://github.com/e-sites/iOS-Suite)**.

---

**The** E-sites Swift iOS API Client used for standard restful API's with default support for OAuth2.

[![forthebadge](http://forthebadge.com/images/badges/made-with-swift.svg)](http://forthebadge.com) [![forthebadge](http://forthebadge.com/images/badges/built-with-swag.svg)](http://forthebadge.com)

[![Platform](https://img.shields.io/cocoapods/p/Cobalt.svg?style=flat)](http://cocoadocs.org/docsets/Cobalt)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Cobalt.svg)](http://cocoadocs.org/docsets/Cobalt)
[![Accio compatible](https://img.shields.io/badge/Accio-supported-0A7CF5.svg?style=flat)](https://github.com/JamitLabs/Accio)
[![Travis-ci](https://travis-ci.org/e-sites/Cobalt.svg?branch=master&001)](https://travis-ci.org/e-sites/Cobalt)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)



# Installation

## CocoaPods

Podfile:

```ruby
pod 'Cobalt'
```

And then

```
pod install
```


## Carthage

Cartfile:

```ruby
github "e-sites/Cobalt"
```

And then

```
carthage update
```

## Accio

Add the following dependency to your Package.swift:

```swift
 .package(url: "https://github.com/e-sites/Cobalt", .branch("master")
```

And run:

```shell
accio install
```

# Implementation

Extend the `Cobalt` class to use it in your own API client.

## Initialization

```swift
import Cobalt

class APIClient: Cobalt.Client {
   static let `default` = APIClient()
    
   private init() {
      let config = Cobalt.Config {
         $0.clientID = "my_oauth_client_id"
         $0.clientSecret = "my_oauth_client_secret"
         $0.host = "https://api.domain.com"
      }
      super.init(config: config)
   }
}

```

## Making requests

APIClient uses [Promises by google](https://github.com/google/promises) internally for handling the responses for a request

### Promises

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func users() -> Promise<[User]> {
      let request = Cobalt.Request {
         $0.path = "/users"
         $0.parameters = [
            "per_page": 10
         ]
      }
		
      return self.request(request).then { json: JSON -> Promise<[User]> in
         let users = try json.map(to: [User].self)
         return Promise(users)
      }.catch { error in
         print("Error: \(error)")
      }
   }
}
```

### RxSwift

Extend the above class with:

```swift
import RxSwift

extension Reactive where Base: Cobalt.Client {
   func users() -> Observable<[User]> {
      return self.users().asObservable()
   }
}
```
And use it like so:

```swift
APIClient.default.rx.users() // ... rxswift etc.
```

### Regular closures

Not in the need for Promises or RxSwift, you can also use regular closures:

```swift
extension Promise {
    func closure(_ handler: @escaping ((Value?, Error?) -> Void)) {
        self.then { value in
            handler(value, nil)
        }.catch { error in
            handler(nil, error)
        }
    }
}
```

And then use it like this:

```swift
APIClient.default.users().closure { users, error 
    // ... Handle it
}
```

## OAuth2

If you want to login a user using the OAuth2 protocol, use the `login()` function from the `Cobalt` class.
Internally it will handle the retrieval and refreshing of the provided `access_token`:

```swift
func login(email: String, password: String) -> Promise<Void>
```

You can also use other options of authentication

### `password`

If you want to retrieve the user profile, you need the `.oauth2(.password)` authenication, that way the request will only succeed if the user has requested an access_token through the `login()` function.   
If the access_token is expired, Cobalt will automatically refresh it, using the refresh_token

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func profile() -> Promise<User> {
        let request = Cobalt.Request({
            $0.authentication = .oauth2(.password)
            $0.path = "/user/profile"
        })

        return request(request).then { json -> Promise<User> in
            let user = try json["data"].map(to: User.self)
            return Promise(user)
        }
    }
}

```
### `client_credentials`

You have to provide the `.oauth2(.clientCredentials)` authentication for the `Cobalt.Request`

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func register(email: String, password: String) -> Promise<Void> {
      let request = Cobalt.Request({
            $0.httpMethod = .post
            $0.path = "/register"
            $0.authentication = .oauth2(.clientCredentials)
            $0.parameters = [
                "email": email,
                "password": password
            ]
        })

        return request(request).then { json -> Promise<Void> in
            return Promise(())
        }
    }
```

This way Cobalt will know that the request needs a `client_credentials` grant_type with an access-token.    
If the user already has an access_token with that grant_type, Cobalt will use it. Else it will request a new access_token for you


### Clearing the access_token

To remove the access_token from its memory and keychain, use:

```swift
func clearAccessToken()
```

# Logging
If you want to use (debug) logging, create a custom logger class which implements `Cobalt.Logger`:

```swift
public protocol Cobalt.Logger {
    func verbose(_ items: Any...)
    func warning(_ items: Any...)
    func debug(_ items: Any...)
    func success(_ items: Any...)
    func error(_ items: Any...)
    func request(_ items: Any...)
    func response(_ items: Any...)
    func info(_ items: Any...)
    func log(_ items: Any...)
}
```

And then use the `Cobalt.Config.logger` property to assign your logged to the `Cobalt` configuration.

# Development

Run `carthage bootstrap` and open `_.xcodeproj`