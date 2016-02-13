#include "hierarchy.h"

#include "content_distribution_visitor.h"
#include "parameters.h"

#include <tr1/memory>

int main(int argc, char** argv) {

  google::InitGoogleLogging(argv[0]);
  google::ParseCommandLineFlags(&argc, &argv, true);

  VLOG(0) << "starting hierarchy builder ...";

  CHECK( FLAGS_action.compare("") );

  string hierarchy_filename_in = FLAGS_model_in;
  string hierarchy_filename_out = FLAGS_model_out;
  string hierarchy_action = FLAGS_action;

  /* by default we don't update the underlying model */
  bool update_model = false;

  /* build hierarchy (from STDIN for now) */
  tr1::shared_ptr<Hierarchy> hierarchy;

  if ( !hierarchy_action.compare("build") ) {
    
    /* build hierarchy (from STDIN for now) */
    hierarchy = tr1::shared_ptr<Hierarchy>(Hierarchy::build(""));

    update_model = true;

  }
  else {

    /* reload hierarchy */
    VLOG(0) << "reloading hierarchy from file ...";
    tr1::shared_ptr<Hierarchy> hierarchy2(Hierarchy::load(hierarchy_filename_in));

    update_model = true;

#if 0

    if ( !hierarchy_action.compare("content-distribution") ) {
      
      /* compute content distributions in an in-order fashion */
      VLOG(0) << "computing content distributions ...";
      
      ContentDistributionVisitor cdv;
      hierarchy->depth_first_search(cdv);
     
      update_model = true;
      
    }

    else if ( !hierarchy_action.compare("dump") ) {

      VLOG(0) << "dump hierarchy ...";
      /* dump content of reloaded hierarchy */
      hierarchy2->dump();

    }
    else {
      
      VLOG(0) << "unknown action ...";
      CHECK(0);

    }

#endif

  }

  if ( update_model ) {
    VLOG(0) << "serializing model to file: " << hierarchy_filename_out;
    hierarchy->serialize(hierarchy_filename_out);
  }

  return 0;

}
