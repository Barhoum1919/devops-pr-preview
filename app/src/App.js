import React from 'react';
import './App.css';

function App() {
  // Safe extraction of env variables
  const version = process.env.REACT_APP_VERSION || 'development';
  const buildTime = process.env.REACT_APP_BUILD_TIME || new Date().toISOString();
  const gitSha = (process.env.REACT_APP_GIT_SHA || 'local').substring(0, 8);
  const prNumber = process.env.REACT_APP_PR_NUMBER || 'main';

  return (
    <div className="App">
      <header className="App-header">
        <h1>Hello from PR  </h1>

        <div className="build-info">
          <h2>Build Information</h2>
          <p><strong>Version:</strong> {version}</p>
          <p><strong>Build Time:</strong> {buildTime}</p>
          <p><strong>Git SHA:</strong> {gitSha}</p>
          <p>
            <strong>Environment:</strong>{' '}
            {prNumber === 'main' ? 'Production' : `PR #${prNumber}`}
          </p>
        </div>

        <div className="feature-demo">
          <h3>Features</h3>
          <ul>
            <li>✅ Containerized Deployment</li>
            <li>✅ NGINX Reverse Proxy</li>
            <li>✅ HTTPS with Let's Encrypt</li>
            <li>✅ GitHub Actions CI/CD</li>
            <li>✅ Container Registry (GHCR)</li>
            <li>✅ PR Preview URLs</li>
          </ul>
        </div>
      </header>
    </div>
  );
}

export default App;
