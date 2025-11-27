import { Building2, ChevronRight } from 'lucide-react';

interface Branch {
  id: string;
  name: string;
}

interface BranchSelectionProps {
  branches: Branch[];
  onSelect: (branchId: string) => void;
  onBack: () => void;
}

export function BranchSelection({ branches, onSelect, onBack }: BranchSelectionProps) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-blue-50 flex items-center justify-center p-4">
      <div className="w-full max-w-2xl bg-white rounded-2xl shadow-xl p-8 md:p-12">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-gradient-to-br from-green-500 to-blue-600 rounded-2xl mb-4">
            <Building2 className="w-8 h-8 text-white" />
          </div>
          <h2 className="text-gray-900 mb-2">접근 가능한 지점 선택</h2>
          <p className="text-gray-600">
            관리하실 지점을 선택해주세요
          </p>
        </div>

        <div className="space-y-3">
          {branches.map((branch) => (
            <button
              key={branch.id}
              onClick={() => onSelect(branch.id)}
              className="w-full flex items-center justify-between p-5 border-2 border-gray-200 rounded-xl hover:border-green-500 hover:bg-green-50 transition-all group"
            >
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-blue-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <Building2 className="w-6 h-6 text-white" />
                </div>
                <span className="text-lg text-gray-900 font-medium">{branch.name}</span>
              </div>
              <ChevronRight className="w-5 h-5 text-gray-400 group-hover:text-green-600 group-hover:translate-x-1 transition-all" />
            </button>
          ))}
        </div>

        <div className="mt-8 pt-8 border-t border-gray-200">
          <button
            onClick={onBack}
            className="w-full py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            다시 로그인
          </button>
        </div>
      </div>
    </div>
  );
}
