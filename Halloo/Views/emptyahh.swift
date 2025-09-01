import SwiftUI

struct EmptyView: View {
    var body: some View {
        VStack {
            Text("Hello, Canvas!")
                .font(.largeTitle)
                .padding()
            
            Button("Tap me") {
                print("Button tapped!")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

struct Emptyview_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
