//
//  OAuth2.swift
//  HexavilleAuth
//
//  Created by Yuki Takei on 2017/05/31.
//
//

import Foundation
import HexavilleFramework

public enum OAuth2Error: Error {
    case invalidAuthrozeURL(String)
}

#if os(Linux)
let _urlSessionShared = URLSession(configuration: URLSessionConfiguration(), delegate: nil, delegateQueue: nil)
    extension URLSession {
        static var shared: URLSession {
            return _urlSessionShared
        }
    }
#endif

extension URLSession {
    func resumeSync(with request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let chan = Channel<(Error?, (HTTPURLResponse, Data)?)>.make(capacity: 1)
        
        let task = self.dataTask(with: request) { data, response, error in
            if let error = error {
                try! chan.send((error, nil))
                return
            }
            try! chan.send((nil, (response as! HTTPURLResponse, data!)))
        }
        
        task.resume()
        
        let (err, tupple) = try chan.receive()
        if let error = err {
            throw error
        }
        return (tupple!.0, tupple!.1)
    }
}

public class OAuth2 {
    let consumerKey: String
    let consumerSecret: String
    let authorizeURL: String
    var accessTokenURL: String?
    let responseType: String
    let callbackURL: CallbackURL
    let scope: String
    
    public init(consumerKey: String, consumerSecret: String, authorizeURL: String, accessTokenURL: String? = nil, responseType: String = "code", callbackURL: CallbackURL, scope: String) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.authorizeURL = authorizeURL
        self.accessTokenURL = accessTokenURL
        self.responseType = responseType
        self.scope = scope
        self.callbackURL = callbackURL
    }
    
    private func dictionary2Query(_ dict: [String: String]) -> String {
        return dict.map({ "\($0.key)=\($0.value)" }).joined(separator: "&")
    }
    
    public func createAuthorizeURL() throws -> URL {
        let params = [
            "client_id": consumerKey,
            "redirect_uri": callbackURL.absoluteURL()!.absoluteString,
            "response_type": responseType,
            "scope": scope
        ]
        
        let queryString = dictionary2Query(params)
        
        guard let url = URL(string: "\(authorizeURL)?\(queryString)") else {
            throw OAuth2Error.invalidAuthrozeURL("\(authorizeURL)?\(queryString)")
        }
        
        return url
    }
    
    public func getAccessToken(request: Request) throws -> Credential {
        guard let code = request.queryItems.filter({ $0.name == "code" }).first?.value else {
            throw HexavilleAuthError.codeIsMissingInResponseParameters
        }
        let urlString = self.accessTokenURL!
        let url = URL(string: urlString)!
        
        let body: [String] = [
            "client_id=\(self.consumerKey)",
            "client_secret=\(self.consumerSecret)",
            "code=\(code)",
            "grant_type=authorization_code",
            "redirect_uri=\(self.callbackURL.absoluteURL()!.absoluteString)"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.joined(separator: "&").data
        
        let (response, bodyData) = try URLSession.shared.resumeSync(with: request)
        
        guard (200..<300).contains(response.statusCode) else {
            var headers: Headers = [:]
            for el in response.allHeaderFields {
                headers[el.key.description] = "\(el.value)"
            }
            
            let response = Response(
                status: Response.Status(statusCode: response.statusCode),
                headers: headers,
                body: bodyData
            )
            
            throw HexavilleAuthError.responseError(response)
        }
        
        do {
            let bodyDictionary = try JSONSerialization.jsonObject(with: bodyData, options: []) as! [String: Any]
            return try Credential(withDictionary: bodyDictionary)
        } catch {
            throw error
        }
    }
    
}

