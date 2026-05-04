import SwiftUI
import StoreKit
import Combine

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
    @Environment(\.offerCodeRedemption) private var offerCodeRedemption
    
    var isLimitedTimeOffer: Bool = false
    var isFromOnboarding: Bool = false
    var isReassessment: Bool = false
    var onDismiss: (() -> Void)? = nil
    
    // Internal override to force offer UI if the global offer is active
    private var isEffectivelyLimitedOffer: Bool {
        isLimitedTimeOffer || (subscriptionManager.isOfferActive && !subscriptionManager.hasActiveSubscription)
    }
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing: Bool = false
    @State private var timeRemaining: String = "12:00:00"
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @ViewBuilder
    private func digitBox(_ char: Character) -> some View {
        Text(String(char))
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 28, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red)
            )
    }

    @ViewBuilder
    private func timerView() -> some View {
        HStack(spacing: 4) {
            let digits = Array(timeRemaining)
            ForEach(0..<digits.count, id: \.self) { index in
                let char = digits[index]
                if char == ":" {
                    Text(":")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.horizontal, 2)
                } else {
                    digitBox(char)
                }
            }
        }
    }

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

    private func currencyFormatter(for product: Product) -> Decimal.FormatStyle.Currency {
        return product.priceFormatStyle.presentation(.narrow)
    }

    private func formattedPrice(for product: Product) -> String {
        product.displayPrice
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
    }

    private func updateCountdown() {
        guard let expiry = subscriptionManager.offerExpiryDate else {
            timeRemaining = "00:00:00"
            return
        }
        
        let now = Date()
        let diff = expiry.timeIntervalSince(now)
        
        if diff <= 0 {
            timeRemaining = "EXPIRED"
            return
        }
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        
        timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // Determine a baseline monthly price to compare savings against (use the highest per-month price among products)
    private func baselineMonthlyPrice() -> Double? {
        let perMonth = subscriptionManager.products.compactMap { monthlyEquivalentPrice($0) }
        return perMonth.max()
    }

    private func savingsString(for product: Product) -> String? {
        if isEffectivelyLimitedOffer {
            return "Save 70%"
        }
        guard let productPerMonth = monthlyEquivalentPrice(product), let baseline = baselineMonthlyPrice(), 
        baseline > 0 else { return nil }
        let fraction = 1.0 - (productPerMonth / baseline)
        let percent = Int(round(fraction * 100.0))
        guard percent > 0 else { return nil }
        return "Save \(percent)%"
    }

    private func adjustedPriceString(for product: Product) -> String {
        let priceValue = product.price
        if isEffectivelyLimitedOffer {
            let discounted = priceValue * 0.3
            return discounted.formatted(currencyFormatter(for: product))
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
        }
        return formattedPrice(for: product)
    }

    private func adjustedWeeklyPriceString(for product: Product) -> String {
        guard let subscription = product.subscription else { return adjustedPriceString(for: product) }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        let weeks: Decimal
        switch unit {
        case .day: weeks = Decimal(value) / 7.0
        case .week: weeks = Decimal(value)
        case .month: weeks = Decimal(value) * 30.4375 / 7.0
        case .year: weeks = Decimal(value) * 365.2425 / 7.0
        @unknown default:
            weeks = Decimal(value)
        }

        guard weeks > 0 else { return adjustedPriceString(for: product) }
        let priceValue = isEffectivelyLimitedOffer ? product.price * 0.3 : product.price
        let perWeek = priceValue / weeks

        return perWeek.formatted(currencyFormatter(for: product))
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "") + "/wk"
    }

    private var expirationMessage: String? {
        let now = Date()
        if let expirationDate = subscriptionManager.latestSubscriptionExpiration, expirationDate > now {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.year, .month, .day, .hour]
            formatter.unitsStyle = .full
            formatter.maximumUnitCount = 1
            if let timeString = formatter.string(from: now, to: expirationDate) {
                return "Your Trackerio Pro will end in \(timeString)"
            }
        } else if subscriptionManager.isTrialActive, let trialEnd = subscriptionManager.trialEndDate, trialEnd > now {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour]
            formatter.unitsStyle = .full
            formatter.maximumUnitCount = 1
            if let timeString = formatter.string(from: now, to: trialEnd) {
                return "Your Trackerio Pro will end in \(timeString)"
            }
        }
        return nil
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
                        if isEffectivelyLimitedOffer {
                            VStack(spacing: 8) {
                                Text("LIMITED TIME OFFER")
                                    .font(.caption)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .cornerRadius(8)
                                
                                Text("70% OFF")
                                    .font(.system(size: 64, weight: .black, design: .rounded))
                                    .foregroundStyle(proBadgeGradient)
                                    .padding(.vertical, -10)
                                
                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                        Text("OFFER EXPIRES IN")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                                    
                                    timerView()
                                }
                                .padding(.top, 12)
                            }
                            .padding(.top, 20)
                            .onReceive(timer) { _ in
                                updateCountdown()
                            }
                            .onAppear {
                                if isEffectivelyLimitedOffer && subscriptionManager.offerExpiryDate == nil {
                                    subscriptionManager.startOfferCountdown()
                                }
                                updateCountdown()
                            }
                        } else {
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

                            Text("Get unlimited feature access with Trackerio Pro.")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }

                        ZStack(alignment: .top) {
                            // 4. Features Summary (now a reusable component)
                            ProFeaturesListView(categories: [
                                ProBenefitCategory(name: "Nutrition Tracking", image: "leaf.fill", color: .green, benefits: [
                                    ProBenefit(icon: "chart.pie.fill", title: "Macros", description: "Track unlimited macronutrients and calories."),
                                    ProBenefit(icon: "pills.fill", title: "Supplements", description: "Log unlimited supplements and vitamins."),
                                    ProBenefit(icon: "fork.knife", title: "Meal Planning", description: "Access full meal planning features."),
                                    ProBenefit(icon: "heart.fill", title: "Cravings", description: "Monitor your cravings with full access."),
                                    ProBenefit(icon: "clock.fill", title: "Intermittent Fasting", description: "Access full intermittent fasting features.")
                                ]),
                                ProBenefitCategory(name: "Routine Management", image: "checklist.checked", color: .blue, benefits: [
                                    ProBenefit(icon: "list.bullet", title: "Daily Tasks", description: "Create unlimited daily tasks to stay organised."),
                                    ProBenefit(icon: "timer", title: "Timers", description: "Create unlimited activity timers for your routines."),
                                    ProBenefit(icon: "target", title: "Goals", description: "Set and track unlimited goals."),
                                    ProBenefit(icon: "repeat", title: "Habits", description: "Add unlimited habits to improve your lifestyle."),
                                    ProBenefit(icon: "dollarsign.circle.fill", title: "Expense Tracker", description: "Manage your expenses with unlimited entries.")
                                ]),
                                ProBenefitCategory(name: "Workout Features", image: "figure.strengthtraining.traditional", color: .orange, benefits: [
                                    ProBenefit(icon: "chart.bar.fill", title: "Weekly Progress", description: "Access unlimited weekly workout progress tracking."),
                                    ProBenefit(icon: "capsule.fill", title: "Workout Supplements", description: "Log unlimited workout supplements.")
                                ]),
                                ProBenefitCategory(name: "Sports & Itinerary", image: "airplane", color: .pink, benefits: [
                                    ProBenefit(icon: "sportscourt.fill", title: "Sports Features", description: "Unlock all sports tracking features."),
                                    ProBenefit(icon: "airplane", title: "Itinerary Features", description: "Enjoy full access to itinerary-related functionalities.")
                                ])
                            ])
                            .padding(.top, 10)

                            Text("Included with Trackerio Pro")
                                .font(.footnote)
                                .padding(10)
                                .adaptiveGlassEffect(in: .rect(cornerRadius: 12.0))
                                .offset(y: -10)
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
                                
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 12) {
                                            ForEach(Array(subscriptionManager.products.enumerated()), id: \.element.id) { index, product in
                                                SubscriptionOptionCard(
                                                    product: product,
                                                    tag: index == 1 ? "Most Popular" : (index == 2 ? "Best Value" : nil),
                                                    savings: savingsString(for: product),
                                                    isSelected: selectedProduct?.id == product.id,
                                                    priceString: adjustedPriceString(for: product),
                                                    weeklyPriceString: adjustedWeeklyPriceString(for: product),
                                                    action: { selectedProduct = product }
                                                )
                                                .id(product.id)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    // Scroll to the selected (middle) product when selection changes
                                    .onChange(of: selectedProduct?.id) { _, newId in
                                        guard let newId else { return }
                                        withAnimation(.easeInOut) {
                                            proxy.scrollTo(newId, anchor: .center)
                                        }
                                    }
                                    .onAppear {
                                        // Attempt to center the pre-selected product when view appears
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            if let id = selectedProduct?.id {
                                                proxy.scrollTo(id, anchor: .center)
                                            }
                                        }
                                    }
                                }
                            }

                            // if let message = expirationMessage {
                            //     Text(message)
                            //         .font(.caption2)
                            //         .foregroundColor(.secondary)
                            //         .padding(.top, 8)
                            // }
                        }

                        Text("By tapping Continue, you will be charged, your subscription will auto-renew for the same price and package length until you cancel via App Store Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        
                        // Text("Debug Region: \(subscriptionManager.storefrontLocale.identifier) (Raw: \(subscriptionManager.storefrontCountryCode ?? "nil"))")
                        //     .font(.caption)
                        //     .foregroundStyle(.gray)
                        //     .padding(.top, 8)
                    }
                }
                .padding(.bottom, 100) // Extra bottom padding to avoid overlap with CTA
                
                // Sticky CTA Button
                VStack {
                    Spacer()
                    Button(action: {
                        if let product = selectedProduct {
                            isPurchasing = true
                            Task {
                                do {
                                    try await subscriptionManager.purchase(product)
                                    isPurchasing = false
                                    // Dismiss if purchase granted
                                    if subscriptionManager.hasProAccess {
                                        dismiss()
                                    }
                                } catch {
                                    isPurchasing = false
                                    // Surface error via subscription manager so UI can show it
                                    subscriptionManager.errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }) {
                        ZStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Continue")
                                .opacity(isPurchasing ? 0 : 1)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedProduct == nil || subscriptionManager.isLoading ? Color.gray : Color.accentColor)
                        .cornerRadius(16)
                        .shadow(color: (selectedProduct == nil || subscriptionManager.isLoading ? Color.gray : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(selectedProduct == nil || isPurchasing || subscriptionManager.isLoading)
                    .padding(.horizontal)
                    
                    if isFromOnboarding {
                        Button(action: {
                            if isEffectivelyLimitedOffer && isLimitedTimeOffer {
                                onDismiss?()
                            }
                            dismiss()
                        }) {
                            Text("Continue with 3 Day Trial")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                        .padding(.bottom, 10)
                    }
                    
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
                                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                    openURL(url)
                                }
                            }) {
                                Text("Terms of Use (EULA)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Text("•")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                if let url = URL(string: "https://ambreon.com/trackerio-privacy") {
                                    openURL(url)
                                }
                            }) {
                                Text("Privacy Policy")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.bottom, 6)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        offerCodeRedemption()
                    } label: {
                        Text("Redeem")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(isLimitedTimeOffer)
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
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let product: Product
    let tag: String?
    let savings: String?
    let isSelected: Bool
    let priceString: String
    let weeklyPriceString: String
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
                            .foregroundColor(.accentColor)
                            .padding(.top, 24)
                            .padding(.trailing, 30)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(priceString)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        HStack(alignment: .center) {
                            Text(weeklyPriceString)
                              .font(.footnote)
                              .foregroundStyle(.primary)
                            Spacer()
                            if let savings {
                                Text(savings)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .adaptiveGlassEffect(in: .rect(cornerRadius: 12.0))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical)
                .padding(.horizontal, 24)
            }
            .frame(width: 260)
            .frame(minHeight: 100)
            .adaptiveGlassEffect(in: .rect(cornerRadius: 16.0))
            .overlay(
                RoundedRectangle(cornerRadius: 16.0)
                    .stroke(isSelected ? Color.accentColor.opacity(0.85) : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16.0))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
        guard let subscription = product.subscription else { return formattedPrice(for: product) }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        let weeks: Decimal
        switch unit {
        case .day: weeks = Decimal(value) / 7.0
        case .week: weeks = Decimal(value)
        case .month: weeks = Decimal(value) * 30.4375 / 7.0
        case .year: weeks = Decimal(value) * 365.2425 / 7.0
        @unknown default:
            weeks = Decimal(value)
        }

        guard weeks > 0 else { return formattedPrice(for: product) }
        let perWeek = product.price / weeks

        return perWeek.formatted(currencyFormatter(for: product))
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "") + "/wk"
    }

    private func strippedProductName(_ name: String) -> String {
        // Remove common App Store product title prefixes like "Pro - " or "Pro Tier - "
        let prefixes = ["Pro - ", "Pro Tier - "]
        for prefix in prefixes {
            if name.hasPrefix(prefix) {
                return String(name.dropFirst(prefix.count))
            }
        }
        return name
    }

    private func currencyFormatter(for product: Product) -> Decimal.FormatStyle.Currency {
        return product.priceFormatStyle.presentation(.narrow)
    }

    private func formattedPrice(for product: Product) -> String {
        product.displayPrice
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
    }
}

#Preview {
    ProSubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}
