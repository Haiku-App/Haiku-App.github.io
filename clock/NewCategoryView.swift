import SwiftUI

struct NewCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var categoryManager: CategoryManager
    @Binding var selectedCategoryId: UUID?
    var theme: AppTheme
    
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColorIndex = 0
    
    let icons = [
        "folder.fill", "briefcase.fill", "doc.text.fill", "book.fill", "graduationcap.fill",
        "pencil.and.outline", "paintbrush.fill", "scissors", "hammer.fill", "wrench.and.screwdriver.fill",
        "car.fill", "airplane", "bus.fill", "tram.fill", "bicycle",
        "cart.fill", "bag.fill", "creditcard.fill", "gift.fill", "tag.fill",
        "house.fill", "building.2.fill", "tent.fill", "tree.fill", "leaf.fill",
        "pawprint.fill", "sun.max.fill", "moon.fill", "cloud.fill", "sparkles",
        "heart.fill", "star.fill", "bolt.fill", "flame.fill", "drop.fill",
        "person.fill", "person.2.fill", "figure.walk", "figure.run", "figure.dance",
        "headphones", "tv.fill", "display", "gamecontroller.fill", "music.note"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Preview
                        VStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(aestheticColors[selectedColorIndex].color)
                            
                            Text(name.isEmpty ? "New Category" : name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.textForeground.opacity(0.8))
                        }
                        .frame(width: 140, height: 140)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(theme.fieldBg)
                                .shadow(color: theme.shadowDark, radius: 8, x: 4, y: 4)
                                .shadow(color: theme.shadowLight, radius: 8, x: -4, y: -4)
                        )
                        .padding(.top, 20)
                        
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY NAME")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(theme.accent)
                                .tracking(1)
                            
                            TextField("Enter name...", text: $name)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(theme.textForeground)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.fieldBg)
                                        .shadow(color: theme.shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: theme.shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COLOR")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(theme.accent)
                                .tracking(1)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<aestheticColors.count, id: \.self) { index in
                                        Button(action: {
                                            selectedColorIndex = index
                                        }) {
                                            Circle()
                                                .fill(aestheticColors[index].color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColorIndex == index ? theme.textForeground : Color.clear, lineWidth: 3)
                                                )
                                                .shadow(color: theme.shadowDark, radius: 3, x: 2, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Icon Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ICON")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(theme.accent)
                                .tracking(1)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 20) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                    }) {
                                        Image(systemName: icon)
                                            .font(.system(size: 24))
                                            .foregroundStyle(selectedIcon == icon ? aestheticColors[selectedColorIndex].color : theme.textForeground.opacity(0.4))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedIcon == icon ? theme.fieldBg : Color.clear)
                                                    .shadow(color: selectedIcon == icon ? theme.shadowDark : Color.clear, radius: 3, x: 2, y: 2)
                                                    .shadow(color: selectedIcon == icon ? theme.shadowLight : Color.clear, radius: 3, x: -2, y: -2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Add Button
                        Button(action: {
                            guard !name.isEmpty else { return }
                            let newCat = Category(name: name, icon: selectedIcon, rgb: aestheticColors[selectedColorIndex])
                            categoryManager.categories.append(newCat)
                            selectedCategoryId = newCat.id
                            AnalyticsManager.shared.capture("category_created", properties: ["icon": selectedIcon])
                            dismiss()
                        }) {
                            Text("Create Category")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(theme.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.accent)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 4)
                                )
                                .opacity(name.isEmpty ? 0.5 : 1.0)
                        }
                        .disabled(name.isEmpty)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .padding(32)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
