import './About.css'

function About() {
  return (
    <div className="about-page">
      <section className="about-hero">
        <h1>About DKUHACK</h1>
        <p className="about-lead">
          DKUHACK is a hackathon event that brings together developers,
          designers, and innovators to create impactful solutions in 48 hours.
        </p>
      </section>

      <section className="about-content">
        <div className="about-card">
          <h2>🎯 Our Mission</h2>
          <p>
            We believe in the power of collaboration and creativity. DKUHACK
            provides a platform for students and professionals to turn their
            ideas into reality, learn new technologies, and make lasting
            connections.
          </p>
        </div>

        <div className="about-card">
          <h2>📅 Event Details</h2>
          <ul className="event-details">
            <li>
              <strong>Date:</strong> Coming Soon
            </li>
            <li>
              <strong>Duration:</strong> 48 hours
            </li>
            <li>
              <strong>Format:</strong> In-person & Virtual
            </li>
            <li>
              <strong>Prizes:</strong> $10,000+ in prizes
            </li>
          </ul>
        </div>

        <div className="about-card">
          <h2>🛠️ Tracks</h2>
          <div className="tracks">
            <div className="track">
              <span className="track-icon">🌱</span>
              <span>Sustainability</span>
            </div>
            <div className="track">
              <span className="track-icon">🤖</span>
              <span>AI / ML</span>
            </div>
            <div className="track">
              <span className="track-icon">🏥</span>
              <span>Healthcare</span>
            </div>
            <div className="track">
              <span className="track-icon">📚</span>
              <span>Education</span>
            </div>
          </div>
        </div>
      </section>
    </div>
  )
}

export default About
