# Cobalt

![Cobalt](Assets/logo.png)

Cobalt is part of the **[E-sites iOS Suite](https://github.com/e-sites/iOS-Suite)**.

---

**The** E-sites Swift iOS API Client used for standard restful API's with default support for OAuth2.

[![forthebadge](http://forthebadge.com/images/badges/made-with-swift.svg)](http://forthebadge.com) [![forthebadge](http://forthebadge.com/images/badges/built-with-swag.svg)](http://forthebadge.com)

[![Travis-ci](https://travis-ci.org/e-sites/Cobalt.svg?branch=master&001)](https://travis-ci.org/e-sites/Cobalt)


# Installation

##Swift PM

**package.swift** dependency:

```swift
.package(url: "https://github.com/e-sites/cobalt.git", from: "7.0.0"),
```

and to your application/library target, add `"Cobalt"` to your `dependencies`, e.g. like this:

```swift
.target(name: "BestExampleApp", dependencies: ["Cobalt"]),
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

APIClient uses Swift's Combine framework internally for handling the responses for a request.

### Combine

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func users() -> AnyPublisher<[User], Cobalt.Error> {
      let request = Cobalt.Request {
         $0.path = "/users"
         $0.parameters = [
            "per_page": 10
         ]
      }
		
      return self.request(request).tryMap { response in
         return try response.map(to: [User].self)
      }.eraseToAnyPublisher()
   }
}
```

## Caching

To utilize disk caching out of the box add the following line to your Podfile:

```
pod 'Cobalt/Cache'
```

And implement it like this:

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func users() -> AnyPublisher<[User], Cobalt.Error> {
      let request = Cobalt.Request {
         $0.path = "/users"
         $0.parameters = [
            "per_page": 10
         ]
         $0.cachingPolicy = .expires(seconds: 60 * 60 * 24) // expires after 1 day
      }
		
      return self.request(request).tryMap { response in
         return try response.map(to: [User].self)
      }.eraseToAnyPublisher()
   }
}
```

To clear the entire cache:

```swift
APIClientInstance.cache.clearAll()
```

## OAuth2

If you want to login a user using the OAuth2 protocol, use the `login()` function from the `Cobalt` class.
Internally it will handle the retrieval and refreshing of the provided `access_token`:

```swift
func login(email: String, password: String) -> AnyPublisher<Void, Cobalt.Error>
```

You can also use other options of authentication

### `password`

If you want to retrieve the user profile, you need the `.oauth2(.password)` authenication, that way the request will only succeed if the user has requested an access_token through the `login()` function.   
If the access_token is expired, Cobalt will automatically refresh it, using the refresh_token

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func profile() -> AnyPublisher<User, Cobalt.Error> {
        let request = Cobalt.Request {
            $0.authentication = .oauth2(.password)
            $0.path = "/user/profile"
        }

        return request(request).tryCompactMap { response in
            if let dictionary = response as? [String: Any], let data = dictionary["data"] as? CobaltResponse {
                return try data.map(to: User.self)
            }
        }.eraseToAnyPublisher()
    }
}

```
### `client_credentials`

You have to provide the `.oauth2(.clientCredentials)` authentication for the `Cobalt.Request`

```swift
class APIClient: Cobalt.Client {
   // ...
   
   func register(email: String, password: String) -> AnyPublisher<Void, Cobalt.Error> {
      let request = Cobalt.Request {
            $0.httpMethod = .post
            $0.path = "/register"
            $0.authentication = .oauth2(.clientCredentials)
            $0.parameters = [
                "email": email,
                "password": password
            ]
        }

        return request(request).map { _ in }
            .eraseToAnyPublisher()
    }
```

This way Cobalt will know that the request needs a `client_credentials` grant_type with an access-token.    
If the user already has an access_token with that grant_type, Cobalt will use it. Else it will request a new access_token for you


### Clearing the access_token

To remove the access_token from its memory and keychain, use:

```swift
func clearAccessToken()
```

# Development

Just open `Cobalt.xcodeproj`