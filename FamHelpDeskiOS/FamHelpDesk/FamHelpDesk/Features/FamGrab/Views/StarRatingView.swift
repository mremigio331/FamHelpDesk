import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    let maxRating: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1 ... maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.4))
                    .onTapGesture {
                        if rating == star {
                            rating = 0 // Tap same star to deselect
                        } else {
                            rating = star
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(rating) out of \(maxRating) stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if rating < maxRating { rating += 1 }
            case .decrement:
                if rating > 0 { rating -= 1 }
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    @Previewable @State var rating = 3
    StarRatingView(rating: $rating)
}
