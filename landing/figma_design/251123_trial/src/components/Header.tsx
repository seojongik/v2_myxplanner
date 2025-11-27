import { Menu } from 'lucide-react';
import { useState } from 'react';

interface HeaderProps {
  onLoginClick: () => void;
}

export function Header({ onLoginClick }: HeaderProps) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
      setMobileMenuOpen(false);
    }
  };

  return (
    <header className="fixed top-0 left-0 right-0 bg-white shadow-md z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 bg-gradient-to-br from-green-500 to-blue-600 rounded-lg flex items-center justify-center">
              <span className="text-white">AG</span>
            </div>
            <span className="text-xl text-gray-900">AutoGolfCRM</span>
          </div>

          {/* Desktop Menu */}
          <nav className="hidden md:flex items-center gap-8">
            <button
              onClick={() => scrollToSection('why')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              Why AutoGolfCRM?
            </button>
            <button
              onClick={() => scrollToSection('features')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              Features
            </button>
            <button
              onClick={() => scrollToSection('pricing')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              Pricing
            </button>
            <button
              onClick={() => scrollToSection('faqs')}
              className="text-gray-700 hover:text-green-600 transition-colors"
            >
              FAQs
            </button>
            <button
              onClick={onLoginClick}
              className="px-6 py-2 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
            >
              CRM Login
            </button>
          </nav>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden p-2"
          >
            <Menu className="w-6 h-6" />
          </button>
        </div>

        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <nav className="md:hidden py-4 border-t">
            <div className="flex flex-col gap-4">
              <button
                onClick={() => scrollToSection('why')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                Why AutoGolfCRM?
              </button>
              <button
                onClick={() => scrollToSection('features')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                Features
              </button>
              <button
                onClick={() => scrollToSection('pricing')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                Pricing
              </button>
              <button
                onClick={() => scrollToSection('faqs')}
                className="text-gray-700 hover:text-green-600 transition-colors text-left"
              >
                FAQs
              </button>
              <button
                onClick={onLoginClick}
                className="px-6 py-2 bg-gradient-to-r from-green-500 to-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity"
              >
                CRM Login
              </button>
            </div>
          </nav>
        )}
      </div>
    </header>
  );
}
