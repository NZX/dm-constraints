require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

if HAS_SQLITE3 || HAS_MYSQL || HAS_POSTGRES
  describe 'DataMapper::Is::NestedSet' do
    before :all do
      class Category
        include DataMapper::Resource
        include DataMapper::Is::NestedSet

        property :id, Integer, :serial => true
        property :name, String
        
        is_a_nested_set
        
        auto_migrate!(:default)
        # convenience method only for speccing.
        def pos; [lft,rgt] end
      end
      
      Category.create!(:id => 1, :name => "Electronics")                            
      Category.create!(:id => 2, :parent_id => 1,  :name => "Televisions")
      Category.create!(:id => 3, :parent_id => 2,  :name => "Tube")
      Category.create!(:id => 4, :parent_id => 2,  :name => "LCD")
      Category.create!(:id => 5, :parent_id => 2,  :name => "Plasma")
      Category.create!(:id => 6, :parent_id => 1,  :name => "Portable Electronics")
      Category.create!(:id => 7, :parent_id => 6,  :name => "MP3 Players")
      Category.create!(:id => 8, :parent_id => 7,  :name => "Flash")
      Category.create!(:id => 9, :parent_id => 6,  :name => "CD Players")
      Category.create!(:id => 10,:parent_id => 6, :name => "2 Way Radios")
      
      # id | lft| rgt| title
      #========================================
      # 1  | 1  | 20 | - Electronics
      # 2  | 2  | 9  |   - Televisions
      # 3  | 3  | 4  |     - Tube
      # 4  | 5  | 6  |     - LCD
      # 5  | 7  | 8  |     - Plasma
      # 6  | 10 | 19 |   - Portable Electronics
      # 7  | 11 | 14 |     - MP3 Players
      # 8  | 12 | 13 |       - Flash
      # 9  | 15 | 16 |     - CD Players
      # 10 | 17 | 18 |     - 2 Way Radios
      
      # |  |  |      |  |     |  |        |  |  |  |  |           |  |  |            |  |              |  |  |
      # 1  2  3      4  5     6  7        8  9  10 11 12  Flash  13 14  15          16  17            18 19 20
      # |  |  | Tube |  | LCD |  | Plasma |  |  |  |  |___________|  |  | CD Players |  | 2 Way Radios |  |  |
      # |  |  |______|  |_____|  |________|  |  |  |                 |  |____________|  |______________|  |  |
      # |  |                                 |  |  |   MP3 Players   |                                    |  |
      # |  |          Televisions            |  |  |_________________|       Portable Electronics         |  |
      # |  |_________________________________|  |_________________________________________________________|  |
      # |                                                                                                    |
      # |                                       Electronics                                                  |
      # |____________________________________________________________________________________________________|
      
    end
    
    describe 'Class#root' do
      it 'should return the toplevel node' do
        Category.root.name.should == "Electronics"
      end
    end
    
    describe 'Class#leaves' do
      it 'should return all nodes without descendants' do
        repository(:default) do
          Category.leaves.length.should == 6
        end
      end
    end
    
    describe '#ancestor, #ancestors and #self_and_ancestors' do
      it 'should return ancestors in an array' do
        repository(:default) do |repos|       
          c8 = Category.get(8)
          c8.ancestor.should == Category.get(7)
          c8.ancestor.should == c8.parent
          
          c8.ancestors.map{|a|a.name}.should == ["Electronics","Portable Electronics","MP3 Players"]
          c8.self_and_ancestors.map{|a|a.name}.should == ["Electronics","Portable Electronics","MP3 Players","Flash"]
        end
      end
    end
    
    describe '#children' do
      it 'should return children of node' do
        r = Category.root
        r.children.length.should == 2
        
        t = r.children.first
        t.children.length.should == 3
        t.children.first.name.should == "Tube"
        t.children[2].name.should == "Plasma"
      end
    end
    
    describe '#descendants and #self_and_descendants' do
      it 'should return all subnodes of node' do
        repository(:default) do
          r = Category.root
          r.self_and_descendants.length.should == 10
          r.descendants.length.should == 9
          
          t = r.children[1]
          t.descendants.length.should == 4
          t.descendants.map{|a|a.name}.should == ["MP3 Players","Flash","CD Players","2 Way Radios"]
        end
      end
    end
    
    describe '#leaves' do
      it 'should return all subnodes of node without descendants' do
        repository(:default) do
          r = Category.root
          r.leaves.length.should == 6
          
          t = r.children[1]
          t.leaves.length.should == 3
        end
      end
    end
    
    describe '#move' do
      
      # Outset:
      # id | lft| rgt| title
      #========================================
      # 1  | 1  | 20 | - Electronics
      # 2  | 2  | 9  |   - Televisions
      # 3  | 3  | 4  |     - Tube
      # 4  | 5  | 6  |     - LCD
      # 5  | 7  | 8  |     - Plasma
      # 6  | 10 | 19 |   - Portable Electronics
      # 7  | 11 | 14 |     - MP3 Players
      # 8  | 12 | 13 |       - Flash
      # 9  | 15 | 16 |     - CD Players
      # 10 | 17 | 18 |     - 2 Way Radios
      
      
      it 'should move items correctly with :higher / :highest / :lower / :lowest' do
        repository(:default) do
          Category[4].pos.should == [5,6]
          
          Category[4].move(:above => Category[3])
          Category[4].pos.should == [3,4]
          
          Category[4].move(:higher).should == false
          Category[4].pos.should == [3,4]
          Category[3].pos.should == [5,6]
          Category[4].right_sibling.should == Category[3]
          
          Category[4].move(:lower)
          Category[4].pos.should == [5,6]
          Category[4].left_sibling.should == Category[3]
          Category[4].right_sibling.should == Category[5]
          
          Category[4].move(:highest)
          Category[4].pos.should == [3,4]
          Category[4].move(:higher).should == false
          
          Category[4].move(:lowest)
          Category[4].pos.should == [7,8]
          Category[4].left_sibling.should == Category[5]
          
          Category[4].move(:higher) # should reset the tree to how it was
          
        end
      end
      
      it 'should move items correctly with :indent / :outdent' do
        repository(:default) do
          Category[7].pos.should == [11,14]
          Category[7].descendants.length.should == 1
          
          # The category is at the top of its parent, should not be able to indent.
          Category[7].move(:indent).should == false
          
          # After doing this, it tries to move into parent again, and throw false...
          Category[7].move(:outdent)
          Category[7].pos.should == [16,19]
          Category[7].left_sibling.should == Category[6]
          
          Category[7].move(:higher) # Move up above Portable Electronics
          
          Category[7].pos.should == [10,13]
          Category[7].left_sibling.should == Category[2]
        end
      end
    end
    
    describe 'moving objects with #move_* #and place_node_at' do
      # it 'should set left/right correctly when adding/moving objects' do
      #   repository(:default) do
      #     Category.auto_migrate!
      #     
      #     c1 = Category.create!(:name => "Electronics")
      #     pos(c1).should == [1,2]
      #     c2 = Category.create(:name => "Televisions")
      #     c2.move :to => 2
      #     pos(c1,c2).should == [1,4, 2,3]
      #     c3 = Category.create(:name => "Portable Electronics")
      #     c3.move :to => 2
      #     pos(c1,c2,c3).should == [1,6, 4,5, 2,3]
      #     c3.move :to => 6
      #     pos(c1,c2,c3).should == [1,6,2,3,4,5]
      #     c4 = Category.create(:name => "Tube")
      #     c4.move :to => 3
      #     pos(c1,c2,c3,c4).should == [1,8,2,5,6,7,3,4]
      #     c4.move :below => c3
      #     pos(c1,c2,c3,c4).should == [1,8,2,3,4,5,6,7]
      #     c2.move :into => c4
      #     pos(c1,c2,c3,c4).should == [1,8,5,6,2,3,4,7]
      #         
      #   end
      # end
      
      it 'should set left/right when choosing a parent' do
        repository(:default) do
          Category.auto_migrate!
          
          c1 = Category.create!(:name => "New Electronics")
          
          c2 = Category.create!(:name => "OLED TVs")
          
          c1.pos.should == [1,4]
          c2.pos.should == [2,3]
          
          c3 = Category.create(:name => "Portable Electronics")
          c3.parent=c1
          c3.save
          
          c1.pos.should == [1,6]
          c2.pos.should == [2,3]
          c3.pos.should == [4,5]
          
          c3.parent=c2
          c3.save
          
          c1.pos.should == [1,6]
          c2.pos.should == [2,5]
          c3.pos.should == [3,4]
          
          c3.parent=c1
          c3.move(:into => c2)
          
          c1.pos.should == [1,6]
          c2.pos.should == [2,5]
          c3.pos.should == [3,4]
          
          c4 = Category.create(:name => "Tube", :parent => c2)
          c5 = Category.create(:name => "Flatpanel", :parent => c2)
          
          c1.pos.should == [1,10]
          c2.pos.should == [2,9]
          c3.pos.should == [3,4]
          c4.pos.should == [5,6]
          c5.pos.should == [7,8]
          
          c5.move(:above => c3)
          c3.pos.should == [5,6]
          c4.pos.should == [7,8]
          c5.pos.should == [3,4]
          
        end
      end
    end
  end
end