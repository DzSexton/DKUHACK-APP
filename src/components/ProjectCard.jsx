import './ProjectCard.css'

function ProjectCard({ title, description, tags, members }) {
  return (
    <div className="project-card">
      <h3 className="project-card-title">{title}</h3>
      <p className="project-card-desc">{description}</p>
      <div className="project-card-tags">
        {tags.map((tag) => (
          <span key={tag} className="tag">
            {tag}
          </span>
        ))}
      </div>
      <div className="project-card-footer">
        <span className="members">👥 {members} members</span>
      </div>
    </div>
  )
}

export default ProjectCard
