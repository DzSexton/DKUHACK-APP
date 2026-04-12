import './Home.css'

function Home() {
  return (
    <div className="home">
      <section className="hero-section">
        <span className="hero-badge">🏆 Hackathon 2026</span>
        <h1 className="hero-title">
          Build. Innovate. <span className="highlight">Ship.</span>
        </h1>
        <p className="hero-subtitle">
          Join the DKUHACK hackathon — collaborate with talented developers,
          designers, and dreamers to build something extraordinary in 48 hours.
        </p>
        <div className="hero-actions">
          <a href="/projects" className="btn btn-primary">
            View Projects
          </a>
          <a href="/about" className="btn btn-secondary">
            Learn More
          </a>
        </div>
      </section>

      <section className="stats-section">
        <div className="stat">
          <span className="stat-number">50+</span>
          <span className="stat-label">Teams</span>
        </div>
        <div className="stat">
          <span className="stat-number">200+</span>
          <span className="stat-label">Participants</span>
        </div>
        <div className="stat">
          <span className="stat-number">48</span>
          <span className="stat-label">Hours</span>
        </div>
        <div className="stat">
          <span className="stat-number">$10K</span>
          <span className="stat-label">In Prizes</span>
        </div>
      </section>

      <section className="features-section">
        <h2 className="section-title">Why DKUHACK?</h2>
        <div className="features-grid">
          <div className="feature-card">
            <span className="feature-icon">💡</span>
            <h3>Innovate</h3>
            <p>Turn your ideas into working prototypes with mentorship and resources.</p>
          </div>
          <div className="feature-card">
            <span className="feature-icon">🤝</span>
            <h3>Collaborate</h3>
            <p>Work with talented people from diverse backgrounds and skill sets.</p>
          </div>
          <div className="feature-card">
            <span className="feature-icon">🚀</span>
            <h3>Launch</h3>
            <p>Ship your project and showcase it to judges and the community.</p>
          </div>
        </div>
      </section>
    </div>
  )
}

export default Home
