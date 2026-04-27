import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import Projects from './pages/Projects'
import { BrowserRouter } from 'react-router-dom'

function renderProjects() {
  return render(
    <BrowserRouter>
      <Projects />
    </BrowserRouter>
  )
}

describe('Projects Page', () => {
  it('renders the page title', () => {
    renderProjects()
    expect(screen.getByText('Hackathon Projects')).toBeInTheDocument()
  })

  it('renders project cards', () => {
    renderProjects()
    expect(screen.getByText('EcoTracker')).toBeInTheDocument()
    expect(screen.getByText('StudyBuddy AI')).toBeInTheDocument()
  })

  it('filters projects based on search input', () => {
    renderProjects()
    const searchInput = screen.getByPlaceholderText(/search projects/i)

    fireEvent.change(searchInput, { target: { value: 'EcoTracker' } })
    expect(screen.getByText('EcoTracker')).toBeInTheDocument()
    expect(screen.queryByText('StudyBuddy AI')).not.toBeInTheDocument()
  })

  it('shows no results message when search has no matches', () => {
    renderProjects()
    const searchInput = screen.getByPlaceholderText(/search projects/i)

    fireEvent.change(searchInput, { target: { value: 'xyznonexistent' } })
    expect(screen.getByText(/no projects match/i)).toBeInTheDocument()
  })

  it('filters projects by tag', () => {
    renderProjects()
    const searchInput = screen.getByPlaceholderText(/search projects/i)

    fireEvent.change(searchInput, { target: { value: 'Python' } })
    expect(screen.getByText('StudyBuddy AI')).toBeInTheDocument()
    expect(screen.getByText('CodeReview Bot')).toBeInTheDocument()
    expect(screen.queryByText('EcoTracker')).not.toBeInTheDocument()
  })
})
