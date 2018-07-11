//
//  Optional.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

func optionalDescription(_ obj: Any?, _ placeholder: String = "(nil)") -> String {
    if let obj = obj {
        return "\(obj)"
    }
    return placeholder
}
