import SwiftUI

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to halloo")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                    
                    Text("Help your elderly loved ones stay connected and maintain their daily routines")
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                        .tracking(-0.5)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Account Setup View
struct AccountSetupView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    Text("Create Your Account")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                        .padding(.top, 50)
                    
                    VStack(spacing: 15) {
                        TextField("Full Name", text: $viewModel.fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        SecureField("Confirm Password", text: $viewModel.confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        TextField("Phone Number", text: $viewModel.phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .keyboardType(.phonePad)
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.previousStep()
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.nextStep()
                        }) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.isValidSignUpForm ? Color.blue : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.isValidSignUpForm)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Quiz View
struct QuizView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Text("Tell Us About Your Needs")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                        .padding(.top, 50)
                    
                    if let question = viewModel.currentQuestion {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(question.question)
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(-0.5)
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                            
                            if let helpText = question.helpText {
                                Text(helpText)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .tracking(-0.3)
                                    .padding(.horizontal, 12)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(question.options, id: \.self) { option in
                                    Button(action: {
                                        viewModel.answerQuestion(option)
                                        if viewModel.currentQuestionIndex >= viewModel.totalQuestions - 1 {
                                            viewModel.nextStep()
                                        }
                                    }) {
                                        Text(option)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 16)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Create Profile View moved to ProfileViews.swift

// MARK: - Onboarding Complete View
struct OnboardingCompleteView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("You're All Set!")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                    
                    Text("You can now start creating daily reminders for your elderly loved ones")
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                        .tracking(-0.5)
                    
                    Spacer()
                    
                    Button(action: {
                        // This will trigger the main app flow
                        viewModel.isComplete = true
                    }) {
                        Text("Start Using halloo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// LoadingView is defined in ContentView.swift