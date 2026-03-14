import type { CSSProperties } from 'react'

// SVG icon paths — Heroicons MIT
// strokeWidth 1.8, viewBox 0 0 24 24

export interface IconDef {
  value: string
  label: string
  paths: string | string[]   // one or more <path d="..."> strings
  extras?: string            // raw SVG child elements for complex icons
}

export const FOLDER_ICONS: IconDef[] = [
  { value: 'folder',     label: 'Folder',     paths: 'M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2V7z' },
  { value: 'eye',        label: 'Eye',        paths: ['M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z', 'M12 9a3 3 0 100 6 3 3 0 000-6z'] },
  { value: 'eye-slash',  label: 'Eye Slash',  paths: ['M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24', 'M1 1l22 22'] },
  { value: 'laptop',     label: 'Laptop',     paths: ['M2 3h20a2 2 0 012 2v11a2 2 0 01-2 2H2a2 2 0 01-2-2V5a2 2 0 012-2z', 'M1 21h22'] },
  { value: 'book',       label: 'Book',       paths: ['M4 19.5A2.5 2.5 0 016.5 17H20', 'M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z'] },
  { value: 'book-open',  label: 'Book Open',  paths: ['M2 3h6a4 4 0 014 4v14a3 3 0 00-3-3H2z', 'M22 3h-6a4 4 0 00-4 4v14a3 3 0 013-3h7z'] },
  { value: 'document',   label: 'Document',   paths: ['M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z', 'M14 2v6h6', 'M16 13H8', 'M16 17H8', 'M10 9H8'] },
  { value: 'phone',      label: 'Phone',      paths: 'M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07A19.5 19.5 0 013.07 10.8a19.79 19.79 0 01-3.07-8.67A2 2 0 012 0h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L6.09 7.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 14.92z' },
  { value: 'camera',     label: 'Camera',     paths: ['M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z', 'M12 9a4 4 0 100 8 4 4 0 000-8z'] },
  { value: 'pencil',     label: 'Pencil',     paths: 'M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z' },
  { value: 'calculator', label: 'Calculator', paths: ['M5 2h14a2 2 0 012 2v16a2 2 0 01-2 2H5a2 2 0 01-2-2V4a2 2 0 012-2z', 'M8 6h8', 'M8 12h2', 'M12 12h2', 'M16 12h2', 'M8 16h2', 'M12 16h2', 'M16 16h2'] },
  { value: 'globe',      label: 'Globe',      paths: ['M12 2a10 10 0 100 20A10 10 0 0012 2z', 'M2 12h20', 'M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z'] },
  { value: 'star',       label: 'Star',       paths: 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z' },
  { value: 'chart',      label: 'Chart',      paths: ['M18 20V10', 'M12 20V4', 'M6 20v-6', 'M2 20h20'] },
  { value: 'flask',      label: 'Science',    paths: ['M9 3h6', 'M9 3v8l-5 9h16l-5-9V3', 'M6 14h12'] },
  { value: 'music',      label: 'Music',      paths: ['M9 18V5l12-2v13', 'M6 18a3 3 0 100 0', 'M18 16a3 3 0 100 0'] },
  { value: 'code',       label: 'Code',       paths: ['M16 18l6-6-6-6', 'M8 6l-6 6 6 6'] },
  { value: 'cpu',        label: 'CPU',        paths: ['M9 2H15', 'M9 22H15', 'M2 9v6', 'M22 9v6', 'M7 2v4M17 2v4M7 18v4M17 18v4M2 7h4M18 7h4M2 17h4M18 17h4', 'M6 6h12v12H6z', 'M9 9h6v6H9z'] },
  { value: 'trophy',     label: 'Trophy',     paths: ['M6 9H3V4h3', 'M18 9h3V4h-3', 'M8 21h8', 'M12 17v4', 'M12 17c-5 0-7-3.5-7-8V4h14v5c0 4.5-2 8-7 8z'] },
]

export const FOLDER_ICON_MAP: Record<string, IconDef> = Object.fromEntries(
  FOLDER_ICONS.map((i) => [i.value, i])
)

interface IconSvgProps {
  icon: IconDef
  size?: number
  style?: CSSProperties
  className?: string
}

export function IconSvg({ icon, size = 16, style, className }: IconSvgProps) {
  const pathArray = Array.isArray(icon.paths) ? icon.paths : [icon.paths]
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      width={size}
      height={size}
      style={style}
      className={className}
    >
      {pathArray.map((d, i) => <path key={i} d={d} />)}
    </svg>
  )
}

/** Renders the icon for a given stored value, falling back to the Folder icon */
export function FolderIconDisplay({ value, size = 16 }: { value?: string; size?: number }) {
  const def = (value && FOLDER_ICON_MAP[value]) || FOLDER_ICON_MAP['folder']
  return <IconSvg icon={def} size={size} />
}
