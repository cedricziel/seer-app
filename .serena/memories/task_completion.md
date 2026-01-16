# Task Completion Checklist

When completing a coding task:

1. **Run linting and formatting**
   ```bash
   make lint && make format
   ```

2. **Use semantic commits** (required by project guidelines)

3. **Never edit .xcodeproj directly** - always modify project.yml and run `make generate`

4. **Follow SwiftUI MVVM patterns** - Views observe @Observable ViewModels
