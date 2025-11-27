import { LucideIcon } from 'lucide-react';

export interface Slide {
  title: string;
  content: React.ReactNode;
}

export interface CardNews {
  title: string;
  subtitle?: string;
  icon: LucideIcon;
  slides: Slide[];
}

export interface Persona {
  text: string;
  subtext: string;
  checked: boolean;
}

export interface Category {
  title: string;
  subtitle: string;
  icon: LucideIcon;
  color: string;
  bgPattern: string;
  personas?: Persona[];
  placeholderSlots?: number;
  cardNewsList: CardNews[];
}
