package main

import (
	"github.com/spf13/cobra"
)

var cmdTesting = &cobra.Command{
	Use:   "testing",
	Short: "Runs testing defined in template",
	Long:  "Runs testing defined in template",
	Run:   RunTesting,
}

func RunTesting(cmd *cobra.Command, args []string) {
	var flags Config
	//fmt.Printf("testrun named %s template %s\n", testingName, testingTemplate)

	config := parse_yaml("defaults.yml")

	prep_error := prepare_deployment(&config, &flags, testingName, "", testingTemplate, "")
	if prep_error != "" {
		die(prep_error)
	}
	_ = create_deployment(config)

}
