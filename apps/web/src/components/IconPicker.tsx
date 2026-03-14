import { useEffect, useRef, useState } from 'react'
import { FOLDER_ICONS, FOLDER_ICON_MAP, IconSvg } from '../config/folderIcons'

interface IconPickerProps {
  value: string
  onChange: (value: string) => void
}

export default function IconPicker({ value, onChange }: IconPickerProps) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  const current = value ? FOLDER_ICON_MAP[value] : null

  return (
    <div className="icon-picker" ref={ref}>
      <button
        type="button"
        className="icon-picker-trigger"
        onClick={() => setOpen((o) => !o)}
        title={current?.label ?? 'Select icon'}
      >
        {current
          ? <><IconSvg icon={current} size={15} /><span>{current.label}</span></>
          : <span className="icon-picker-placeholder">— select icon —</span>
        }
        <span className="icon-picker-chevron">▾</span>
      </button>

      {open && (
        <div className="icon-picker-dropdown">
          <button
            type="button"
            className={`icon-picker-option${!value ? ' selected' : ''}`}
            onClick={() => { onChange(''); setOpen(false) }}
          >
            <span className="icon-picker-option-label">— none —</span>
          </button>
          {FOLDER_ICONS.map((icon) => (
            <button
              key={icon.value}
              type="button"
              className={`icon-picker-option${value === icon.value ? ' selected' : ''}`}
              onClick={() => { onChange(icon.value); setOpen(false) }}
              title={icon.label}
            >
              <IconSvg icon={icon} size={15} />
              <span className="icon-picker-option-label">{icon.label}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
