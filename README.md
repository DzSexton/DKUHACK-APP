# DKUHACK-APP

A hackathon event hub built with React and Vite. Browse projects, learn about the event, and connect with the community.

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18 or later)

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

### Build

```bash
npm run build
```

### Tests

```bash
npm test
```

### Lint

```bash
npm run lint
```

## Project Structure

```
src/
├── components/       # Reusable UI components
│   ├── Navbar.jsx    # Navigation bar
│   ├── Footer.jsx    # Page footer
│   └── ProjectCard.jsx # Project display card
├── pages/            # Route pages
│   ├── Home.jsx      # Landing page
│   ├── Projects.jsx  # Project gallery with search
│   └── About.jsx     # About the hackathon
├── test/             # Test setup
├── App.jsx           # Root app with routing
└── main.jsx          # Entry point
```

## Tech Stack

- **React** — UI library
- **Vite** — Build tool
- **React Router** — Client-side routing
- **Vitest** — Testing framework
- **Testing Library** — Component testing utilities
