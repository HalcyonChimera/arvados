package config

import (
	"fmt"
	"io/ioutil"

	"github.com/ghodss/yaml"
)

// LoadFile loads configuration from the file given by configPath and
// decodes it into cfg.
//
// YAML and JSON formats are supported.
func LoadFile(cfg interface{}, configPath string) error {
	buf, err := ioutil.ReadFile(configPath)
	if err != nil {
		return err
	}
	err = yaml.Unmarshal(buf, cfg)
	if err != nil {
		return fmt.Errorf("Error decoding config %q: %v", configPath, err)
	}
	return nil
}
