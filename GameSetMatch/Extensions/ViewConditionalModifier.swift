//
//  ViewConditionalModifier.swift
//  GameSetMatch
//
//  Created by Ashamaz on 18/3/24.
//

import SwiftUI

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
