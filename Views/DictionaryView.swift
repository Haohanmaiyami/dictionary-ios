//
//  Dictinary.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI

struct DictionaryView: View {
    var body: some View {
        TabView {
            DictionaryMainView()
                .tabItem {
                    Label("Словарь", systemImage: "book")
                }
            AIView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
    }
}
            
