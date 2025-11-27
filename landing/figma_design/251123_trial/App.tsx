import { useState } from 'react';
import { Header } from './components/Header';
import { Hero } from './components/Hero';
import { WhyAutoGolfCRM } from './components/WhyAutoGolfCRM';
import { Features } from './components/Features';
import { Pricing } from './components/Pricing';
import { FAQs } from './components/FAQs';
import { Login } from './components/Login';

export default function App() {
  const [showLogin, setShowLogin] = useState(false);

  if (showLogin) {
    return <Login onBack={() => setShowLogin(false)} />;
  }

  return (
    <div className="min-h-screen bg-white">
      <Header onLoginClick={() => setShowLogin(true)} />
      <Hero />
      <WhyAutoGolfCRM />
      <Features />
      <Pricing />
      <FAQs />
      
      <footer className="bg-gray-900 text-white py-12">
        <div className="container mx-auto px-4 text-center">
          <p>&copy; 2025 AutoGolfCRM. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
}
