// Note : next iteration of the model, this time with multiple slot types (i.e. gappy pattern distributions)
// TODO : can this be achieved through inheritance ?

/* get slot type dp */
DirichletProcess< GappyPatternProcess>& Corpus::get_slot_type_dp() {

  return _slot_type_dp;

}
