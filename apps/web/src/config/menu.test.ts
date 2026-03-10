import { describe, it, expect } from 'vitest'
import { MENU_BY_ROLE, Role } from './menu'

describe('MENU_BY_ROLE', () => {
  const roles: Role[] = ['learner', 'teacher', 'admin', 'parent']

  it('exports an entry for every expected role', () => {
    roles.forEach((role) => {
      expect(MENU_BY_ROLE[role]).toBeDefined()
    })
  })

  it('every role has at least one menu item', () => {
    roles.forEach((role) => {
      expect(MENU_BY_ROLE[role].length).toBeGreaterThan(0)
    })
  })

  it('every menu item has a label and path', () => {
    roles.forEach((role) => {
      MENU_BY_ROLE[role].forEach((item) => {
        expect(item.label).toBeTruthy()
        expect(item.path).toBeTruthy()
      })
    })
  })

  it('teacher Content Studio has children', () => {
    const studio = MENU_BY_ROLE.teacher.find((i) => i.label === 'Content Studio')
    expect(studio).toBeDefined()
    expect(studio!.nested).toBe(true)
    expect(studio!.children!.length).toBeGreaterThan(0)
  })

  it('Content Studio children have label and path', () => {
    const studio = MENU_BY_ROLE.teacher.find((i) => i.label === 'Content Studio')
    studio!.children!.forEach((child) => {
      expect(child.label).toBeTruthy()
      expect(child.path).toMatch(/^\/teacher\/content-studio\//)
    })
  })
})
