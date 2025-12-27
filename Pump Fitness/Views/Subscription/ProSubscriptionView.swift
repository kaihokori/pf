import SwiftUI
import StoreKit

struct ProBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct ProBenefitCategory: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let color: Color
    let benefits: [ProBenefit]
}

struct ProSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    
    @State private var selectedProduct: Product?
    
    private var proBadgeGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.74, green: 0.43, blue: 0.97),
                Color(red: 0.83, green: 0.99, blue: 0.94)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Compute monthly-equivalent price for a product using its subscription period
    private func monthlyEquivalentPrice(_ product: Product) -> Double? {
        guard let subscription = product.subscription else { return nil }
        let period = subscription.subscriptionPeriod
        let value = Double(period.value)

        let months: Double
        switch period.unit {
        case .day:
            months = value / 30.4375
        case .week:
            months = (value * 7.0) / 30.4375
        case .month:
            months = value
        case .year:
            months = value * 12.0
        @unknown default:
            months = value
        }

        guard months > 0 else { return nil }
        let priceDouble = NSDecimalNumber(decimal: product.price).doubleValue
        return priceDouble / months
    }

    // Determine a baseline monthly price to compare savings against (use the highest per-month price among products)
    private func baselineMonthlyPrice() -> Double? {
        let perMonth = subscriptionManager.products.compactMap { monthlyEquivalentPrice($0) }
        return perMonth.max()
    }

    private func savingsString(for product: Product) -> String? {
        guard let productPerMonth = monthlyEquivalentPrice(product), let baseline = baselineMonthlyPrice(), 
        baseline > 0 else { return nil }
        let fraction = 1.0 - (productPerMonth / baseline)
        let percent = Int(round(fraction * 100.0))
        guard percent > 0 else { return nil }
        return "Save \(percent)%"
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.74, green: 0.43, blue: 0.97),
                            Color(red: 0.83, green: 0.99, blue: 0.94),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 260)
                    .opacity(0.3)
                    
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
 
                ScrollView {
                    VStack {
                        // 1. Header
                        HStack(alignment: .center, spacing: 8) {
                            Image("logo")
                                .resizable()
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 30)
                            
                            Text("Trackerio")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            Text("PRO")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(proBadgeGradient)
                                )
                        }
                        
                        // 2. Hero Text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get unlimited tracking and access to all features with Trackerio Pro")
                                .font(.title3)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical)
                        .padding(.horizontal, 10)

                        ZStack(alignment: .top) {
                            // 4. Features Summary
                            VStack(alignment: .leading, spacing: 24) {
                                VStack {
                                    HStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.primary)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Unlimited macro, supplement, daily task tracking + more")
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    HStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.primary)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Increased limits on timers, habits + more")
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    // Unlock pro features
                                    HStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.primary)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Full access to expense tracking, travel planning + more")
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                }
                                .padding()
                            }
                            .padding(.top, 10)
                            .glassEffect(in: .rect(cornerRadius: 16.0))
                            .padding(.horizontal, 18)

                            Text("Included with Trackerio Pro")
                                .font(.footnote)
                                .padding(10)
                                .glassEffect(in: .rect(cornerRadius: 12.0))
                                .offset(y: -20)
                        }
                        .padding(.top)
                        
                        
                        
                        // 3. Subscription Options Carousel
                        if subscriptionManager.isLoading {
                            ProgressView()
                                .frame(height: 200)
                        } else if let error = subscriptionManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding()
                        } else {
                            VStack(alignment: .leading) {
                                Text("Select a Plan")
                                  .font(.body)
                                  .foregroundStyle(.secondary)
                                  .multilineTextAlignment(.center)
                                  .padding(.horizontal)
                                  .padding(.top)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(Array(subscriptionManager.products.enumerated()), id: \.element.id) { index, product in
                                            SubscriptionOptionCard(
                                                product: product,
                                                tag: index == 1 ? "Most Popular" : (index == 2 ? "Best Value" : nil),
                                                savings: savingsString(for: product),
                                                isSelected: selectedProduct?.id == product.id,
                                                action: { selectedProduct = product }
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                
                // Sticky CTA Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    await subscriptionManager.restore()
                                }
                            }) {
                                Text("Restore")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Text("•")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                if let url = URL(string: "https://kaihokori.github.io/trackerio-legal/") {
                                    openURL(url)
                                }
                            }) {
                                Text("Terms, Conditions & Privacy")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    Button(action: {
                        // Prevent attempting to purchase if the user already has Pro
                        guard !subscriptionManager.hasProAccess else { return }

                        if let product = selectedProduct {
                            Task {
                                do {
                                    try await subscriptionManager.purchase(product)
                                    // Dismiss if purchase granted
                                    if subscriptionManager.hasProAccess {
                                        dismiss()
                                    }
                                } catch {
                                    // Surface error via subscription manager so UI can show it
                                    subscriptionManager.errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }) {
                        Text(subscriptionManager.hasProAccess ? "You are a Pro Member" : "Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background((selectedProduct == nil || subscriptionManager.hasProAccess) ? Color.gray : Color.blue)
                            .cornerRadius(16)
                            .shadow(color: ((selectedProduct == nil || subscriptionManager.hasProAccess) ? Color.gray : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(selectedProduct == nil || subscriptionManager.hasProAccess)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .background(
                        LinearGradient(colors: [(colorScheme == .dark ? Color.black : Color.white).opacity(0), (colorScheme == .dark ? Color.black : Color.white)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 100)
                            .padding(.bottom, -20)
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.title2)
                    }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
                if selectedProduct == nil, let middle = subscriptionManager.products.dropFirst().first {
                    selectedProduct = middle
                } else if selectedProduct == nil {
                    selectedProduct = subscriptionManager.products.first
                }
            }
            .onChange(of: subscriptionManager.products) { _, products in
                 if selectedProduct == nil, let middle = products.dropFirst().first {
                    selectedProduct = middle
                } else if selectedProduct == nil {
                    selectedProduct = products.first
                }
            }
        }
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let tag: String?
    let savings: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding([.top, .trailing], 24)
                    }
                }
                VStack(alignment: .leading) {
                    if let tag {
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    Text(strippedProductName(product.displayName))
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .padding(.top, tag != nil ? 0 : 16)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    // Total price for the subscription (displayed above the weekly equivalent)
                    Spacer()
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack {
                        // Per week
                        Text(weeklyPriceString(for: product))
                          .font(.subheadline)
                          .fontWeight(.semibold)
                        Spacer()
                        if let savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.semibold)
                                // Place in a capsule
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .glassEffect(in: .rect(cornerRadius: 12.0))
                        }
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 260)
        .frame(minHeight: 160)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .overlay(
            RoundedRectangle(cornerRadius: 16.0)
                .stroke(isSelected ? Color.blue.opacity(0.85) : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16.0))
        .padding(.vertical, 6)
    }
    
    func subscriptionPeriodString(_ period: Product.SubscriptionPeriod) -> String {
        let unit = period.unit
        let value = period.value
        
        var unitString = ""
        switch unit {
        case .day: unitString = "day"
        case .week: unitString = "week"
        case .month: unitString = "month"
        case .year: unitString = "year"
        @unknown default: unitString = "period"
        }
        
        if value == 1 {
            return "/\(unitString)"
        } else {
            return "every \(value) \(unitString)s"
        }
    }

    func weeklyPriceString(for product: Product) -> String {
        guard let subscription = product.subscription else { return product.displayPrice }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        let weeks: Double
        switch unit {
        case .day: weeks = Double(value) / 7.0
        case .week: weeks = Double(value)
        case .month: weeks = Double(value) * 30.4375 / 7.0
        case .year: weeks = Double(value) * 365.2425 / 7.0
        @unknown default:
            weeks = Double(value)
        }

        let priceDouble = NSDecimalNumber(decimal: product.price).doubleValue
        guard weeks > 0 else { return product.displayPrice }
        let perWeek = priceDouble / weeks

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return (formatter.string(from: NSNumber(value: perWeek)) ?? product.displayPrice) + "/wk"
    }

    private func strippedProductName(_ name: String) -> String {
        // Remove an App Store product title prefix like "Pro - " if present
        let prefix = "Pro - "
        if name.hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }
}

#Preview {
    ProSubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}
