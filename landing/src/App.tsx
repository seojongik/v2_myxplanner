import { useState } from 'react';
import { Header } from './components/Header';
import { Hero } from './components/Hero';
import { WhyAutoGolfCRM } from './components/WhyAutoGolfCRM';
import { Features } from './components/Features';
import { Pricing } from './components/Pricing';
import { FAQs } from './components/FAQs';
import { Login } from './components/Login';
import { Register } from './components/Register';
import { Footer } from './components/Footer';

export default function App() {
  const [showLogin, setShowLogin] = useState(false);
  const [showRegister, setShowRegister] = useState(false);

  if (showLogin) {
    return <Login onBack={() => setShowLogin(false)} onRegisterClick={() => { setShowLogin(false); setShowRegister(true); }} />;
  }

  if (showRegister) {
    return <Register onBack={() => setShowRegister(false)} onLoginClick={() => { setShowRegister(false); setShowLogin(true); }} />;
  }

  return (
    <div className="min-h-screen bg-white">
      <Header onLoginClick={() => setShowLogin(true)} onRegisterClick={() => setShowRegister(true)} />
      <Hero onRegisterClick={() => setShowRegister(true)} />
      <WhyAutoGolfCRM />
      <Features />
      <Pricing onLoginClick={() => setShowLogin(true)} onRegisterClick={() => setShowRegister(true)} />
      <FAQs />
      <Footer />
    </div>
  );
}
