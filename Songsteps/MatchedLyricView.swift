import SwiftUI

struct MatchedLyricView: View {
    let matchResult: LyricMatchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("匹配结果")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("匹配率: \(Int(matchResult.matchPercentage))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 原歌词匹配展示
            FlowLayout(spacing: 4) {
                ForEach(matchResult.originalWords.indices, id: \.self) { index in
                    let word = matchResult.originalWords[index]
                    Text(word.word)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(word.isMatched ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(word.isMatched ? .green : .red)
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 流式布局视图
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return arrangeSubviews(sizes: sizes, proposal: proposal).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = arrangeSubviews(sizes: sizes, proposal: proposal).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                         proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let width = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var maxY: CGFloat = 0
        
        for size in sizes {
            if currentPosition.x + size.width > width {
                currentPosition.x = 0
                currentPosition.y = maxY + spacing
            }
            
            offsets.append(currentPosition)
            
            currentPosition.x += size.width + spacing
            maxY = max(maxY, currentPosition.y + size.height)
        }
        
        return (offsets, CGSize(width: width, height: maxY))
    }
} 