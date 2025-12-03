/**
 * 비밀번호 검증 서비스
 * bcrypt, SHA-256, 평문 비밀번호 모두 지원
 */

// bcryptjs는 브라우저에서도 동작하는 bcrypt 구현
import bcrypt from 'bcryptjs';

/**
 * 비밀번호 해시 타입 확인
 */
export function getHashType(password: string): 'bcrypt' | 'sha256' | 'plain' {
  if (password.startsWith('$2')) {
    return 'bcrypt';
  } else if (password.length === 50 && /^[a-f0-9]+$/.test(password)) {
    return 'sha256';
  } else {
    return 'plain';
  }
}

/**
 * SHA-256 해시 생성 (기존 시스템 호환성용)
 */
async function hashPasswordSha256(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  // SHA-256은 64자이지만, 기존 시스템은 50자로 자름
  return hashHex.substring(0, 50);
}

/**
 * 비밀번호 검증 (bcrypt, SHA-256, 평문 모두 지원)
 */
export async function verifyPassword(
  inputPassword: string,
  storedPassword: string
): Promise<boolean> {
  const cleanInput = inputPassword.trim();
  const cleanStored = storedPassword.trim();

  console.log('🔐 비밀번호 검증:');
  console.log('  - 입력: "' + cleanInput + '" (길이: ' + cleanInput.length + ')');
  console.log('  - 저장: "' + cleanStored + '" (길이: ' + cleanStored.length + ')');

  // 1. bcrypt 해시 확인 ($2a$, $2b$, $2y$로 시작)
  if (cleanStored.startsWith('$2')) {
    try {
      const result = await bcrypt.compare(cleanInput, cleanStored);
      console.log('  - bcrypt 검증 결과: ' + result);
      return result;
    } catch (e) {
      console.error('  - bcrypt 검증 오류: ' + e);
      return false;
    }
  }

  // 2. 기존 SHA-256 해시 확인 (50자 hex 문자열)
  const isSha256Hash = cleanStored.length === 50 && /^[a-f0-9]+$/.test(cleanStored);

  if (isSha256Hash) {
    // SHA-256 해시와 비교 (하위 호환성)
    const hashedInput = await hashPasswordSha256(cleanInput);
    console.log('  - SHA-256 검증 결과: ' + (hashedInput === cleanStored));
    return hashedInput === cleanStored;
  }

  // 3. 평문 비밀번호와 직접 비교 (하위 호환성 - 점진적 제거 권장)
  const result = cleanInput === cleanStored;
  console.log('  - 평문 비교: "' + cleanInput + '" == "' + cleanStored + '" → ' + result);
  return result;
}

/**
 * 비밀번호 해싱 (bcrypt 사용)
 */
export async function hashPassword(password: string): Promise<string> {
  // bcrypt 사용 (Salt 자동 생성)
  const salt = await bcrypt.genSalt(10);
  return await bcrypt.hash(password, salt);
}






