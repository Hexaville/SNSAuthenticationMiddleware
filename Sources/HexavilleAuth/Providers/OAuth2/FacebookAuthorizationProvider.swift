//
//  FacebookAuthorizationProvider.swift
//  HexavilleAuth
//
//  Created by Yuki Takei on 2017/05/30.
//
//

import Foundation
import HexavilleFramework

public enum FacebookAuthorizationProviderError: Error {
    case bodyShouldBeAJSON
}

public struct FacebookAuthorizationProvider: OAuth2AuthorizationProvidable {
    
    public let path: String
    
    public let oauth: OAuth2
    
    public let callback: RespodWithCredential
    
    public init(path: String, consumerKey: String, consumerSecret: String, callbackURL: CallbackURL, scope: String, callback: @escaping RespodWithCredential) {
        self.path = path
        
        self.oauth = OAuth2(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            authorizeURL: "https://www.facebook.com/dialog/oauth",
            accessTokenURL: "https://graph.facebook.com/oauth/access_token",
            callbackURL: callbackURL,
            scope: scope
        )
        
        self.callback = callback
    }
    
    public func authorize(request: Request) throws -> (Credential, LoginUser)  {
        let credential = try self.getAccessToken(request: request)
        let url = URL(string: "https://graph.facebook.com/me?fields=id,name,email,picture,gender&access_token=\(credential.accessToken)")!
        let (response, data) = try URLSession.shared.resumeSync(with: URLRequest(url: url))
        
        guard (200..<300).contains(response.statusCode) else {
            throw HexavilleAuthError.responseError(response.transform(withBodyData: data))
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw FacebookAuthorizationProviderError.bodyShouldBeAJSON
        }
        
        var picture: String?
        if let _picture = json["picture"] as? [String: Any], let data = _picture["data"] as? [String: Any] {
            picture = data["url"] as? String
        }
        let user = LoginUser(
            id: json["id"] as? String ?? "",
            name: json["name"] as? String ?? "",
            screenName: json["name"] as? String,
            email: json["email"] as? String,
            picture: picture,
            raw: json
        )
        return (credential, user)
    }
}
