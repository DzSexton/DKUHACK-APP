import { useState } from 'react'
import ProjectCard from '../components/ProjectCard'
import './Projects.css'

const SAMPLE_PROJECTS = [
  {
    id: 1,
    title: 'EcoTracker',
    description:
      'A sustainability dashboard that tracks and visualizes your carbon footprint across daily activities.',
    tags: ['React', 'Node.js', 'Charts'],
    members: 4,
  },
  {
    id: 2,
    title: 'StudyBuddy AI',
    description:
      'An AI-powered study assistant that generates flashcards and quizzes from your course notes.',
    tags: ['Python', 'AI/ML', 'Flask'],
    members: 3,
  },
  {
    id: 3,
    title: 'CampusConnect',
    description:
      'A platform for students to find and join campus events, clubs, and study groups.',
    tags: ['React', 'Firebase', 'Mobile'],
    members: 5,
  },
  {
    id: 4,
    title: 'HealthPulse',
    description:
      'A health monitoring app that aggregates data from wearables and provides wellness insights.',
    tags: ['React Native', 'API', 'Health'],
    members: 3,
  },
  {
    id: 5,
    title: 'CodeReview Bot',
    description:
      'An automated code review assistant that provides suggestions and detects common vulnerabilities.',
    tags: ['Python', 'GitHub API', 'Security'],
    members: 2,
  },
  {
    id: 6,
    title: 'FoodShare',
    description:
      'A community app to reduce food waste by connecting people with surplus food to those in need.',
    tags: ['Vue.js', 'Maps', 'Social'],
    members: 4,
  },
]

function Projects() {
  const [search, setSearch] = useState('')

  const filteredProjects = SAMPLE_PROJECTS.filter(
    (project) =>
      project.title.toLowerCase().includes(search.toLowerCase()) ||
      project.description.toLowerCase().includes(search.toLowerCase()) ||
      project.tags.some((tag) =>
        tag.toLowerCase().includes(search.toLowerCase())
      )
  )

  return (
    <div className="projects-page">
      <div className="projects-header">
        <h1>Hackathon Projects</h1>
        <p>Explore innovative projects built during DKUHACK</p>
        <input
          type="text"
          className="search-input"
          placeholder="Search projects by name, description, or tech..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          aria-label="Search projects"
        />
      </div>

      <div className="projects-grid">
        {filteredProjects.map((project) => (
          <ProjectCard key={project.id} {...project} />
        ))}
      </div>

      {filteredProjects.length === 0 && (
        <div className="no-results">
          <p>No projects match your search. Try different keywords!</p>
        </div>
      )}
    </div>
  )
}

export default Projects
