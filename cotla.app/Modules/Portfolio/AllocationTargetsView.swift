//
//  AllocationTargetsView.swift
//  cotla.app
//

import SwiftUI
import UIKit

/// Metas de alocação por categoria e onde colocar o aporte do mês para chegar mais perto delas.
struct AllocationTargetsView: View {
    /// Valor em carteira hoje, por categoria.
    let current: [AssetKind: Double]

    @State private var percentTexts: [AssetKind: String] = AllocationPlan.loadTargets().mapValues { AllocationTargetsView.number($0 * 100) }
    @State private var amountText = ""

    private static let brazil = Locale(identifier: "pt_BR")

    private var total: Double { current.values.reduce(0, +) }

    /// Campos de texto (atualizam a cada tecla, ao contrário de TextField com formato). Aceita vírgula ou ponto.
    private var targets: [AssetKind: Double] {
        percentTexts.compactMapValues { Double($0.replacingOccurrences(of: ",", with: ".")) }.mapValues { $0 / 100 }
    }

    private var targetSum: Double { targets.values.reduce(0, +) * 100 }
    private var isComplete: Bool { abs(targetSum - 100) < 0.01 }
    private var amount: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        Form {
            Section {
                ForEach(AssetKind.allCases, id: \.self) { kind in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(uiColor: kind.color))
                            .frame(width: 10, height: 10)
                        Text(kind.title)
                        Spacer()
                        Text("hoje \(Self.percent(share(of: kind)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("0", text: binding(for: kind))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 52)
                        Text("%")
                    }
                }
            } header: {
                Text("Metas")
            } footer: {
                Text(isComplete ? "As metas somam 100%." : "As metas somam \(Self.number(targetSum))%. Ajuste até dar 100%.")
                    .foregroundStyle(isComplete ? Color.secondary : Color.red)
            }

            Section("Aporte do mês") {
                HStack {
                    Text("R$")
                    TextField("0,00", text: $amountText)
                        .keyboardType(.decimalPad)
                }
            }

            if isComplete, amount > 0 {
                plan
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: percentTexts) {
            AllocationPlan.saveTargets(targets)
        }
    }

    private var plan: some View {
        let contributions = AllocationPlan.contributions(current: current, targets: targets, amount: amount)
        let kinds         = AssetKind.allCases.filter { (targets[$0] ?? 0) > 0 || (current[$0] ?? 0) > 0 }

        return Section {
            ForEach(kinds, id: \.self) { kind in
                let value = contributions[kind] ?? 0
                let after = ((current[kind] ?? 0) + value) / (total + amount)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(kind.title).font(.headline)
                        Spacer()
                        Text(value >= 0.005 ? value.asCurrency : "—")
                            .font(.headline)
                            .foregroundStyle(value >= 0.005 ? Color("BrandGreen") : Color.secondary)
                    }
                    Text("\(Self.percent(share(of: kind))) → \(Self.percent(after)) · meta \(Self.percent(targets[kind] ?? 0))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Onde aportar")
        } footer: {
            Text("Sem vender nada: o aporte vai para as categorias abaixo da meta, até ficarem igualmente perto dela. "
                 + "As que já passaram da meta não recebem.")
        }
    }

    private func share(of kind: AssetKind) -> Double {
        total > 0 ? (current[kind] ?? 0) / total : 0
    }

    private func binding(for kind: AssetKind) -> Binding<String> {
        Binding(get: { percentTexts[kind] ?? "" }, set: { percentTexts[kind] = $0 })
    }

    private static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0...1)).locale(brazil))
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(brazil))
    }
}
