KRL Test Harness
============

Test harness for KRL rulesets

usage: ./krl-test.pl [-h?] -c config_file.yml

 -h|?      : this (help) message
 -c file   : configuration file
 -v        : vebose, print diagnostic messges
 -d        : pring details accompanying diagnostics. 

example: ./krl-test.pl -c test_AWS.yml -vd


The test harness uses a test configuration YAML file to know what tests to run. The test config file looks like this:

    # cloudos_test@kynetx.com/for_testing
    eci: 07E6569E-6CE9-11E3-81D7-05AA87B7806A 
    rules_engine: kibdev.kobj.net

    test_1:
      desc: "AWS Module Test"
      domain: test
      type: store_item
      attributes:
         foo: bar
      rids:
         - b503129x1.prod
    
The eci is a channel to a pico where the test rulesets, the rulesets to be tested, and the test module ruleset have been installed. The rules engine will default to ```kibdev``` if not specified. 

Each test is in a structure with a name that starts with ```test_```.  And structure with a name with that prefix will be run. In this case, there’s just one, the event ```test:store_item```.

You can add attributes as shown. 

If a rids array is present the event will be raised for those rids rather than generally to all installed rulesets. 

If a configuration file is not specified, the file test_config.yml in the current directory will be used. 


## Dependencies

- Getopt::Std
- Data::Dumper
- YAML::XS
- Kinetic::Raise  // included

