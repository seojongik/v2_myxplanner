import { X } from 'lucide-react';

interface FeatureDetail {
  title: string;
  description: string;
  image: string;
  benefits: string[];
}

interface FeatureModalProps {
  feature: FeatureDetail | null;
  onClose: () => void;
}

export function FeatureModal({ feature, onClose }: FeatureModalProps) {
  if (!feature) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div
        className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sticky top-0 bg-white border-b border-gray-200 p-6 flex items-center justify-between">
          <h3 className="text-2xl font-bold text-gray-900">{feature.title}</h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-6 h-6 text-gray-600" />
          </button>
        </div>

        <div className="p-6">
          {feature.image && (
            <div className="mb-6 rounded-lg overflow-hidden bg-gray-100">
              <img
                src={feature.image}
                alt={feature.title}
                className="w-full h-64 object-cover"
              />
            </div>
          )}

          <p className="text-gray-700 text-lg mb-6 leading-relaxed">
            {feature.description}
          </p>

          {feature.benefits.length > 0 && (
            <div>
              <h4 className="font-semibold text-gray-900 mb-3">주요 혜택</h4>
              <ul className="space-y-2">
                {feature.benefits.map((benefit, index) => (
                  <li key={index} className="flex items-start gap-2">
                    <span className="text-green-500 mt-1">✓</span>
                    <span className="text-gray-700">{benefit}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
