import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var xVelocity: CGFloat
    var yVelocity: CGFloat
    var scale: CGFloat
    var color: Color
    var rotation: Double
    var rotationSpeed: Double
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?
    
    let colors: [Color] = [.blue, .green, .pink, .orange, .yellow, .cyan]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: 8 * particle.scale, height: 8 * particle.scale)
                        .position(x: particle.x, y: particle.y)
                        .rotationEffect(.degrees(particle.rotation))
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                startAnimation(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createParticles(in size: CGSize) {
        for _ in 0..<100 {
            let particle = ConfettiParticle(
                x: size.width / 2,
                y: size.height / 2,
                xVelocity: CGFloat.random(in: -10...10),
                yVelocity: CGFloat.random(in: -15...5),
                scale: CGFloat.random(in: 0.5...1.5),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -10...10)
            )
            particles.append(particle)
        }
    }
    
    private func startAnimation(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            for i in particles.indices {
                particles[i].x += particles[i].xVelocity
                particles[i].y += particles[i].yVelocity
                particles[i].yVelocity += 0.4 // gravity
                particles[i].rotation += particles[i].rotationSpeed
            }
            // Remove particles that fell off screen
            particles.removeAll { $0.y > size.height + 20 }
            
            if particles.isEmpty {
                timer?.invalidate()
            }
        }
    }
}
