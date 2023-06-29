package main

import (
	"bufio"
	"github.com/konveyor/analyzer-lsp/provider"
	"gopkg.in/yaml.v3"
	"io"
	"os"
	"path"
	"strings"
)

//
// Settings - provider settings file.
type Settings []provider.Config

//
// Read file.
func (r *Settings) Read() (err error) {
	f, err := os.Open(r.path())
	if err != nil {
		return
	}
	defer func() {
		_ = f.Close()
	}()
	b, err := io.ReadAll(f)
	err = yaml.Unmarshal(b, r)
	return
}

//
// Write file.
func (r *Settings) Write() (err error) {
	f, err := os.Create(r.path())
	if err != nil {
		return
	}
	defer func() {
		_ = f.Close()
	}()
	b, err := yaml.Marshal(r)
	if err != nil {
		return
	}
	_, err = f.Write(b)
	return
}

//
// Location update the location on each provider.
func (r *Settings) Location(path string) {
	for i := range *r {
		p := &(*r)[i]
		p.InitConfig[0].Location = path
	}
}

//
// Mode update the mode on each provider.
func (r *Settings) Mode(mode provider.AnalysisMode) {
	for i := range *r {
		p := &(*r)[i]
		switch p.Name {
		case "java":
			p.InitConfig[0].AnalysisMode = mode
		}
	}
}

//
// MavenSettings set maven settings path.
func (r *Settings) MavenSettings(path string) {
	if path == "" {
		return
	}
	for i := range *r {
		p := &(*r)[i]
		switch p.Name {
		case "java":
			p.InitConfig[0].ProviderSpecificConfig["mavenSettingsFile"] = path
		}
	}
}

//
// Log self to activity.
func (r *Settings) Log() {
	b, _ := yaml.Marshal(r)
	addon.Activity("Settings: %s", r.path())
	reader := strings.NewReader(string(b))
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		addon.Activity("> %s", scanner.Text())
	}
}

//
// Path
func (r *Settings) path() (p string) {
	return path.Join(OptDir, "settings.json")
}
