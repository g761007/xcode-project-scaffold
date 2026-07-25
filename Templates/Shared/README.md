# {{PROJECT_NAME}}

{{PLATFORM_DISPLAY_NAME}} app built with {{INTERFACE_DISPLAY_NAME}}, targeting {{PLATFORM_DISPLAY_NAME}} {{DEPLOYMENT_TARGET}} and later.

## Getting started

`{{PROJECT_NAME}}.xcodeproj` is **not** in version control. It is generated from
`project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen), which is how
this project avoids merge conflicts in a file no one can read.

```bash
{{SETUP_COMMANDS}}
make generate                # produce {{CONTAINER_FILE}}
make open                    # ...or generate it and open Xcode in one step
```

Open `{{CONTAINER_FILE}}`, not anything else in this directory.

## Commands

```bash
make generate    # regenerate {{CONTAINER_FILE}} from project.yml
make build       # build for {{BUILD_TARGET_DESCRIPTION}}
make test        # run the tests
make lint        # swiftformat --lint and swiftlint --strict
make format      # apply formatting in place
```

`make lint` needs `swiftlint` and `swiftformat`
(`brew install swiftlint swiftformat`).

## Architecture

{{ARCHITECTURE}}

## Layout

```text
{{PROJECT_NAME}}/
├── App/              application sources
├── Resources/        asset catalogue and other bundled files
├── Tests/            unit tests
├── Makefile          the commands above
├── project.yml       the project definition — edit this, not the .xcodeproj
├── scaffold.yml      a record of the settings this project was created from
├── .gitignore
├── .swiftformat      formatting rules
└── .swiftlint.yml    lint rules
```

`Tests/`, `.swiftformat` and `.swiftlint.yml` are present only if this project
was created with them enabled.

### `project.yml` and `scaffold.yml`

`project.yml` describes the Xcode project and is **the file to edit** when you
add a target, a dependency or a build setting.

`scaffold.yml` records what
[xscaffold](https://github.com/g761007/xcode-project-scaffold) was asked for
when this project was created. Nothing reads it afterwards; it is kept so that
the original intent stays visible. Changing it does not change the project.
