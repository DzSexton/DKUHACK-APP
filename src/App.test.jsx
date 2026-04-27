import { render, screen } from '@testing-library/react'
import { BrowserRouter } from 'react-router-dom'
import { describe, it, expect } from 'vitest'
import App from './App'

function renderApp() {
  return render(
    <BrowserRouter>
      <App />
    </BrowserRouter>
  )
}

describe('App', () => {
  it('renders the navbar with DKUHACK brand', () => {
    renderApp()
    const brand = screen.getByRole('link', { name: /🚀 DKUHACK/ })
    expect(brand).toBeInTheDocument()
    expect(brand).toHaveClass('navbar-brand')
  })

  it('renders navigation links', () => {
    renderApp()
    const navLinks = screen.getAllByRole('link')
    const navTexts = navLinks.map((link) => link.textContent)
    expect(navTexts).toEqual(expect.arrayContaining(['Home', 'Projects', 'About']))
  })

  it('renders the footer', () => {
    renderApp()
    expect(screen.getByText(/built with/i)).toBeInTheDocument()
  })

  it('renders the home page by default', () => {
    renderApp()
    expect(screen.getByText(/Build\. Innovate\./i)).toBeInTheDocument()
  })
})
