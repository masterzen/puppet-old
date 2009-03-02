class AddUniqueIndex < ActiveRecord::Migration
    def self.up
        # add unique resource index, except for mysql, for which we ask the DBA
        # to do it if she wants, considered the risks.
        if Puppet[:dbadapter] == "mysql"
            Puppet.warning "There is a possibility to add an unique index over resources for better integrity"
            Puppet.warning "Unfortunately, MySQL imposes conditions on index over TEXT columns that makes it risky"
            Puppet.warning "to apply blindly and automatically such index."
            Puppet.warning "The issue is that such index should be a prefix index (ie only the n first characters will be"
            Puppet.warning "covered by the index). This means that with this index in place you must be sure that no"
            Puppet.warning "resource have the same common prefix titles of lenght 255".
            Puppet.warning "As such we will print the command to be executed, but we won't apply it"
            Puppet.warning "ALTER TABLE resources DROP INDEX typentitle, ADD UNIQUE INDEX typentitle (title(255),restype,host_id)"
        else
            remove_index :resources, :column => [:title, :restype]
            add_index :resources, [:title, :restype, :host_id], :unique => true
        end

        add_index :resource_tags, [:resource_id, :puppet_tag_id], :unique => true
        add_index :puppet_tags, :name, :unique => true

        remove_index :hosts, :name
        add_index :hosts, :name, :unique => true

        remove_index :fact_names, :name
        add_index :fact_names, :name, :unique => true

        add_index :param_values, [ :param_name_id, :resource_id ], :unique => true

        remove_index :param_names, :name
        add_index :param_names, :name, :unique => true
    end

    def self.down
        if Puppet[:dbadapter] == "mysql"
            execute "ALTER TABLE resources DROP INDEX typentitle, ADD INDEX typentitle (title(50),restype)"
        else
            remove_index :resources, :column => [:title, :restype, :host_id], :unique => true
            add_index :resources, :column => [:title, :restype]

            remove_index :restouce_tags, [:resource_id, :puppet_tag_id], :unique => true
            remove_index :puppet_tags, :name, :unique => true

            remove_index :hosts, :name, :unique => true
            add_index :hosts, :name

            remove_index :fact_names, :name, :unique => true
            add_index :fact_names, :name

            remove_index :param_values, [ :param_name_id, :resource_id ], :unique => true

            remove_index :param_names, :name, :unique => true
            add_index :param_names, :name
        end
    end
end
