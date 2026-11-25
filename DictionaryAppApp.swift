//
//  DictionaryAppApp.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI

@main
struct DictionaryAppApp: App {
    init() {
        InkFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            DictionaryView()
        }
    }
}
