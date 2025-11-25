//
//  Array+SafeAccess.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import Foundation

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}