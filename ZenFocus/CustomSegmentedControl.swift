import SwiftUI

struct CustomSegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let getLabel: (T) -> String
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selection = option
                    }
                }) {
                    Text(getLabel(option))
                        .font(.system(size: 14, weight: .medium))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selection == option {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor)
                                        .matchedGeometryEffect(id: "SegmentBackground", in: namespace)
                                }
                            }
                        )
                        .foregroundColor(selection == option ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    @Namespace private var namespace
}