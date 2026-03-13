import { describe, it, expect } from 'vitest'
import { MENU_BY_ROLE, SIDEBAR_BY_SECTION, TEACHER_SECTIONS, Role } from './menu'

describe('MENU_BY_ROLE', () => {
  const nonTeacherRoles: Role[] = ['learner', 'admin', 'parent']

  it('exports an entry for every role', () => {
    const roles: Role[] = ['learner', 'teacher', 'admin', 'parent']
    roles.forEach((role) => {
      expect(MENU_BY_ROLE[role]).toBeDefined()
    })
  })

  it('non-teacher roles have at least one menu item', () => {
    nonTeacherRoles.forEach((role) => {
      expect(MENU_BY_ROLE[role].length).toBeGreaterThan(0)
    })
  })

  it('teacher role has no items (uses SIDEBAR_BY_SECTION instead)', () => {
    expect(MENU_BY_ROLE.teacher).toHaveLength(0)
  })

  it('every non-teacher menu item has a label, path, and icon', () => {
    nonTeacherRoles.forEach((role) => {
      MENU_BY_ROLE[role].forEach((item) => {
        expect(item.label).toBeTruthy()
        expect(item.path).toBeTruthy()
        expect(item.icon).toBeTruthy()
      })
    })
  })
})

describe('TEACHER_SECTIONS', () => {
  it('has three sections', () => {
    expect(TEACHER_SECTIONS).toHaveLength(3)
  })

  it('each section has label, path, and defaultPath', () => {
    TEACHER_SECTIONS.forEach((s) => {
      expect(s.label).toBeTruthy()
      expect(s.path).toBeTruthy()
      expect(s.defaultPath).toBeTruthy()
    })
  })
})

describe('SIDEBAR_BY_SECTION', () => {
  it('content-studio section has items with label, path, and icon', () => {
    const items = SIDEBAR_BY_SECTION['/teacher/content-studio']
    expect(items.length).toBeGreaterThan(0)
    items.forEach((item) => {
      expect(item.label).toBeTruthy()
      expect(item.path).toMatch(/^\/teacher\/content-studio\//)
      expect(item.icon).toBeTruthy()
    })
  })
})
