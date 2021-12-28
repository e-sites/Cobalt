# Cobalt

![Cobalt](Assets/logo.png)

Cobalt is part of the **[E-sites iOS Suite](https://github.com/e-sites/iOS-Suite)**.

---

**The** E-sites Swift iOS API Client used for standard restful API's with default support for OAuth2.

[![forthebadge](http://forthebadge.com/images/badges/made-with-swift.svg)](http://forthebadge.com) [![forthebadge](http://forthebadge.com/images/badges/built-with-swag.svg)](http://forthebadge.com)

[![Travis-ci](https://travis-ci.org/e-sites/Cobalt.svg?branch=master&001)](https://travis-ci.org/e-sites/Cobalt)


# Installation

## Swift PM

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
         $0.authentication.path = "/oauth/v2/token"
         $0.authentication.authorizationPath = "/oauth/v2/connect"
         $0.authentication.clientID = "my_oauth_client_id"
         $0.authentication.clientSecret = "my_oauth_client_secret"
         $0.authentication.pkceEnabled = false // Disabled by default
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
         $0.diskCachePolicy = .expires(seconds: 60 * 60 * 24) // expires after 1 day
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
### `authorization_code`

This grant type requires the user to sign in in a webview or browser. To enable this type of authentication, add `.oauth2(.authorizationCode)` to the `Cobalt.Request`.
 If the access_token is expired, Cobalt will automatically refresh it, using the refresh_token.

```swift
class APIClient: Cobalt.Client {
    // ...

    func profile() -> Promise<User> {
        let request = Cobalt.Request({
            $0.authentication = .oauth2(.authorizationCode)
            $0.path = "/user/profile"
        })

        return request(request).then { json -> Promise<User> in
            let user = try json["data"].map(to: User.self)
            return Promise(user)
        }
    }
}

```

Before requesting the profile, the user needs to sign in. To simplify, Cobalt can create an `AuthorizationCodeRequest` for you, which contains the url you need to redirect the user to:

```swift
public struct AuthorizationCodeRequest {
    public var url: URL
    public var redirectUri: String
    public var state: String?
    public var codeVerifier: String?
}

class OAuthAuthenticator {
    // ...
    
    private var presentedViewController: UIViewController?
    
    func login() {
        // Cobalt uses the credentials you provided in the config
        // When you enabled PKCE, Cobalt will also create the code challenge and verifier for you
        // The code verifier is returned to you in the AuthorizationCodeRequest
        client.startAuthorizationFlow(
            scope: ["openid", "profile", "email", "offline_access"],
            redirectUri: "app://oauth/authorized"
        ).subscribe(onSuccess: { [weak self] request in
            self?.request = request
            
            let safariController = SFSafariViewController(url: request.url)
            self?.presentedViewController = UINavigationController(rootViewController: safariController)
            self?.presentedViewController!.setNavigationBarHidden(true, animated: false)
            
            viewController.present(
                (self?.presentedViewController)!,
                animated: true,
                completion: nil
            )
        }, onError: { error in
            print("error: \(error)")
        }).disposed(by: disposeBag)
    }
    
    // You execute this when receiving the callback from: "app://oauth/authorized?code=code&scope=scope&state=state"
    func getAccessToken(from code: String, scope: String? = nil, state: String? = nil) -> Single<Void> {
        defer {
            presentedViewController = nil
        }
        
        if let presentedViewController = presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        // Validate that the state of the callback equals the state created by Cobalt
        // Perform some extra validation by your needs
        if request.state != state {
            return Single<Void>.error(Error.invalidUrl)
        }
        
        client.requestTokenFromAuthorizationCode(initialRequest: request, code: code).subscribe(onSuccess: {
            // The user is signed in successfully 
        }, onError: { error in
            // Something went wrong, notify the user
        })
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
