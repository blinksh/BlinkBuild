//
//  File.swift
//  
//
//  Created by Yury Korolev on 17.06.2021.
//

import Foundation

enum GitURL {
  
  static func from(url: URL) -> URL {
    fromGitlab(url: fromGithub(url: url))
  }
  
  static func fromGitlab(url: URL) -> URL {
    guard
       url.host == "gitlab.com" || url.host == nil && url.path.hasPrefix("gitlab.com/"),
       url.scheme == nil || url.scheme == "https",
       url.pathComponents.count > 2, // [/, org, repo, ...],
       var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
     else {
       return url
     }
     
     
     comps.scheme = nil
     comps.host = nil
     comps.path = comps.path.hasSuffix(".git") ? comps.path : comps.path + ".git"
     if comps.path.hasPrefix("/") {
       comps.path.removeFirst()
     }
     if comps.path.hasSuffix("/") {
       comps.path.removeLast()
     }
     if comps.path.hasPrefix("gitlab.com/") {
       comps.path = comps.path.replacingOccurrences(of: "^gitlab\\.com\\/", with: "", options: .regularExpression, range: nil)
     }

     comps.percentEncodedPath = "git@gitlab.com:" + comps.percentEncodedPath
     
     guard let githubURL = comps.url
     else {
         return url
     }
     return githubURL
  }
  
  static func fromGithub(url: URL) -> URL {
    guard
      url.host == "github.com" || url.host == nil && url.path.hasPrefix("github.com/"),
      url.scheme == nil || url.scheme == "https",
      url.pathComponents.count > 2, // [/, org, repo, ...],
      var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      return url
    }
    
    
    comps.scheme = nil
    comps.host = nil
    comps.path = comps.path.hasSuffix(".git") ? comps.path : comps.path + ".git"
    if comps.path.hasPrefix("/") {
      comps.path.removeFirst()
    }
    if comps.path.hasSuffix("/") {
      comps.path.removeLast()
    }
    if comps.path.hasPrefix("github.com/") {
      comps.path = comps.path.replacingOccurrences(of: "^github\\.com\\/", with: "", options: .regularExpression, range: nil)
    }

    comps.percentEncodedPath = "git@github.com:" + comps.percentEncodedPath
    
    guard let githubURL = comps.url
    else {
        return url
    }
    return githubURL
  }
}
