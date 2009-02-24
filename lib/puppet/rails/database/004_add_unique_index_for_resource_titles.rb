class AddUniqueIndexForResourceTitles < ActiveRecord::Migration
    def self.up
        if Puppet[:dbadapter] == "mysql"
            execute "ALTER TABLE resources DROP INDEX typentitle, ADD UNIQUE INDEX typentitle (title(255),restype,host_id)"
        else
            remove_index :resources, :column => [:title, :restype]
            add_index :resources, [:title, :restype, :host_id], :unique => true
        end
    end

    def self.down
        if Puppet[:dbadapter] == "mysql"
            execute "ALTER TABLE resources DROP INDEX typentitle, ADD INDEX typentitle (title(50),restype)"
        else
            remove_index :resources, :column => [:title, :restype, :host_id], :unique => true
            add_index :resources, :column => [:title, :restype]
        end
    end
end
